import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

/**
 * CE QUE CHAQUE PAGE EMBARQUE, gardé par la structure de ses imports.
 *
 * L'audit de septembre 2026 a mesuré, depuis `.next/diagnostics` :
 *
 * - Zod chargé DEUX fois sur toute page d'administration : les contrats,
 *   consommés par leur `dist` CommonJS, résolvaient `zod/index.cjs`, et
 *   l'admin `zod/index.js`. Deux instances complètes, plus tous les contrats
 *   sans élagage : environ 66 Ko gzip de trop par page.
 * - Les pages publiques ouvertes sur téléphone depuis un e-mail
 *   (`/reset-password`, `/verify-email`) chargeaient Zod « classique »
 *   (65 Ko gzip) pour deux contrôles de longueur et la lecture d'une
 *   enveloppe d'erreur, et `/reset-password` tous les contrats pour deux
 *   constantes.
 *
 * Mesurer un poids demande un build complet ; ces tests en gardent la
 * CAUSE, en quelques millisecondes.
 */

const adminRoot = resolve(__dirname, '../..');
const srcRoot = join(adminRoot, 'src');

describe('les contrats se consomment par leurs SOURCES', () => {
  it('tsconfig pointe @carlys/api-contracts vers src/, jamais vers le dist CommonJS', () => {
    const tsconfig = JSON.parse(readFileSync(join(adminRoot, 'tsconfig.json'), 'utf8')) as {
      compilerOptions: { paths: Record<string, string[]> };
    };
    const paths = tsconfig.compilerOptions.paths;

    expect(paths['@carlys/api-contracts']).toEqual(['../../packages/api-contracts/src/index.ts']);
    for (const [alias, targets] of Object.entries(paths)) {
      for (const target of targets) {
        expect(existsSync(resolve(adminRoot, target.replace('*', '')))).toBe(true);
        expect(`${alias} → ${target}`).not.toMatch(/\/dist\//);
      }
    }
  });
});

/** Les imports de VALEUR d'un fichier (les `import type` s'effacent au build). */
function valueImports(file: string): string[] {
  const source = readFileSync(file, 'utf8');
  const found: string[] = [];
  for (const match of source.matchAll(
    /^\s*(?:import|export)\s+(?!type\s)(?:[\s\S]*?\sfrom\s+)?'([^']+)'/gm,
  )) {
    if (match[1] !== undefined) {
      found.push(match[1]);
    }
  }
  return found;
}

/** Résout un import LOCAL (`@/…` ou relatif) vers son fichier ; `null` pour un paquet. */
function localFile(specifier: string, from: string): string | null {
  let base: string;
  if (specifier.startsWith('@/')) {
    base = join(srcRoot, specifier.slice(2));
  } else if (specifier.startsWith('.')) {
    base = resolve(dirname(from), specifier);
  } else {
    return null;
  }
  for (const candidate of [base, `${base}.ts`, `${base}.tsx`, join(base, 'index.ts')]) {
    if (existsSync(candidate) && statSync(candidate).isFile()) {
      return candidate;
    }
  }
  throw new Error(`Import introuvable : ${specifier} depuis ${from}`);
}

/** Les paquets atteints depuis `entry`, en suivant les imports locaux. */
function packagesReachedFrom(entry: string): Map<string, string> {
  const reached = new Map<string, string>();
  const seen = new Set<string>();
  const queue = [entry];
  while (queue.length > 0) {
    const file = queue.pop() as string;
    if (seen.has(file)) {
      continue;
    }
    seen.add(file);
    for (const specifier of valueImports(file)) {
      const local = localFile(specifier, file);
      if (local === null) {
        reached.set(specifier, file.slice(adminRoot.length + 1));
      } else if (/\.(tsx?|mts)$/.test(local)) {
        queue.push(local);
      }
    }
  }
  return reached;
}

function publicEntries(directory = join(srcRoot, 'app/(public)')): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) {
      return publicEntries(path);
    }
    return /^(page|layout)\.tsx$/.test(entry) ? [path] : [];
  });
}

describe('les pages publiques ne chargent ni Zod classique ni les contrats', () => {
  const entries = [
    ...publicEntries(),
    join(srcRoot, 'app/layout.tsx'),
    join(srcRoot, 'app/providers.tsx'),
  ];

  it('trouve les pages publiques', () => {
    expect(entries.map((entry) => entry.slice(srcRoot.length + 1))).toEqual(
      expect.arrayContaining([
        'app/(public)/reset-password/page.tsx',
        'app/(public)/verify-email/page.tsx',
      ]),
    );
  });

  it.each(entries.map((entry) => [entry.slice(srcRoot.length + 1), entry]))(
    '%s',
    (_name, entry) => {
      const reached = packagesReachedFrom(entry);
      const heavy = [...reached].filter(
        ([specifier]) => specifier === 'zod' || specifier === '@carlys/api-contracts',
      );
      expect(heavy).toEqual([]);
    },
  );

  it('le balai voit un import lourd quand il y en a un', () => {
    const reached = packagesReachedFrom(join(srcRoot, 'lib/admin-api.ts'));
    expect(reached.has('zod')).toBe(true);
    expect(reached.has('@carlys/api-contracts')).toBe(true);
  });
});

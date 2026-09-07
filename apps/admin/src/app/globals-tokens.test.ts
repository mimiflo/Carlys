import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { describe, expect, it } from 'vitest';

/**
 * `globals.css` RECOPIE la palette : l'admin ne dépend pas de
 * `@carlys/design-tokens`, il n'y a donc aucune génération pour l'empêcher de
 * dériver — et il avait déjà dérivé sur deux valeurs sombres.
 *
 * Ce test est le seul lien entre la source de vérité et la copie. Il échoue
 * dans les deux sens : une valeur recopiée qui ne correspond plus au jeton, et
 * une couleur ajoutée à la main sans jeton en face.
 */

/**
 * Racine du dépôt, trouvée en remontant jusqu'au marqueur de l'espace de
 * travail : `import.meta.url` n'est pas une URL `file:` sous jsdom, et le
 * répertoire courant dépend de l'endroit d'où la suite est lancée.
 */
function findRepoRoot(): string {
  let directory = process.cwd();
  for (;;) {
    if (existsSync(join(directory, 'pnpm-workspace.yaml'))) {
      return directory;
    }
    const parent = dirname(directory);
    if (parent === directory) {
      throw new Error(`Racine du dépôt introuvable au-dessus de ${process.cwd()}`);
    }
    directory = parent;
  }
}

const repoRoot = findRepoRoot();

const tokens: unknown = JSON.parse(
  readFileSync(join(repoRoot, 'packages/design-tokens/src/tokens.json'), 'utf8'),
);

const css = readFileSync(join(repoRoot, 'apps/admin/src/app/globals.css'), 'utf8');

/** Valeur textuelle d'un jeton, désignée par son chemin pointé. */
function token(path: string): string {
  const value = path.split('.').reduce<unknown>((node, key) => {
    if (node === null || typeof node !== 'object') {
      return undefined;
    }
    return (node as Record<string, unknown>)[key];
  }, tokens);
  if (typeof value !== 'string') {
    throw new Error(`Jeton absent ou non textuel dans tokens.json : ${path}`);
  }
  return value;
}

/** Déclarations `--x: y;` du premier bloc `:root` d'un fragment de CSS. */
function rootVariables(fragment: string): Record<string, string> {
  const start = fragment.indexOf(':root');
  if (start < 0) {
    throw new Error('Aucun bloc `:root` trouvé dans ce fragment de globals.css');
  }
  const open = fragment.indexOf('{', start);
  const close = fragment.indexOf('}', open);
  if (open < 0 || close < 0) {
    throw new Error('Bloc `:root` non refermé dans globals.css');
  }
  const declarations: Record<string, string> = {};
  for (const [, name, value] of fragment
    .slice(open, close)
    .matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) {
    if (name !== undefined && value !== undefined) {
      declarations[name] = value.trim().toLowerCase();
    }
  }
  return declarations;
}

const DARK_MEDIA = '@media (prefers-color-scheme: dark)';
const darkAt = css.indexOf(DARK_MEDIA);
if (darkAt < 0) {
  throw new Error(`globals.css ne contient plus de bloc « ${DARK_MEDIA} »`);
}

/** Correspondance ASSUMÉE entre chaque variable recopiée et son jeton. */
const LIGHT: Record<string, string> = {
  '--background': 'color.surface.lightBackground',
  '--foreground': 'color.neutral.900',
  '--surface': 'color.surface.lightSurface',
  '--primary': 'color.brand.primary',
  '--primary-dark': 'color.brand.primaryDark',
  '--accent': 'color.brand.accent',
  '--muted': 'color.neutral.500',
  '--danger': 'color.semantic.danger',
  '--success': 'color.semantic.success',
};

const DARK: Record<string, string> = {
  '--background': 'color.surface.darkBackground',
  '--foreground': 'color.neutral.100',
  '--surface': 'color.surface.darkSurface',
  '--muted': 'color.neutral.400',
};

describe.each([
  { theme: 'clair', expected: LIGHT, declared: rootVariables(css.slice(0, darkAt)) },
  { theme: 'sombre', expected: DARK, declared: rootVariables(css.slice(darkAt)) },
])('globals.css — palette $theme fidèle à tokens.json', ({ expected, declared }) => {
  for (const [variable, path] of Object.entries(expected)) {
    it(`${variable} recopie ${path}`, () => {
      expect(`${variable}: ${declared[variable] ?? '(non déclarée)'}`).toBe(
        `${variable}: ${token(path).toLowerCase()}`,
      );
    });
  }

  it('ne déclare aucune couleur sans jeton en face', () => {
    expect(Object.keys(declared).sort()).toEqual(Object.keys(expected).sort());
  });
});

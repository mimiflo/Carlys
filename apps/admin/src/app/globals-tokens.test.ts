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
 *
 * ── Pourquoi la lecture est ce qu'elle est ──────────────────────────────
 *
 * La première version ne lisait que le PREMIER bloc `:root` de chaque moitié
 * du fichier (`indexOf(':root')` puis `indexOf('}')`), et découpait clair /
 * sombre à l'index de `@media (prefers-color-scheme: dark)`. Deux trous
 * mesurés, tous deux verts avant correction :
 *
 * 1. un SECOND bloc `:root` écrasant `--background: #ff0000` passait — soit
 *    parce qu'il n'était jamais lu, soit, s'il se trouvait après le bloc
 *    sombre, parce qu'il était attribué au thème sombre ;
 * 2. une couleur EN DUR dans `@theme inline` passait : ce bloc n'était pas
 *    lu du tout, alors que c'est lui qui alimente les classes Tailwind.
 *
 * D'où : tous les blocs `:root` sont parcourus et fusionnés dans l'ordre du
 * document (la redéfinition ultérieure gagne, comme dans le navigateur), une
 * redéfinition est en plus signalée pour elle-même, le bloc sombre est
 * découpé par appariement d'accolades plutôt que par index, et `@theme
 * inline` doit se borner à republier les variables de `:root`.
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

/**
 * Commentaires retirés d'emblée : ils ne s'appliquent pas, et leurs accolades
 * fausseraient l'appariement ci-dessous.
 */
const css = readFileSync(join(repoRoot, 'apps/admin/src/app/globals.css'), 'utf8').replace(
  /\/\*[\s\S]*?\*\//g,
  '',
);

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

/** Déclarations `--x: y;` d'un corps de bloc, dans l'ordre du document. */
function declarationsOf(body: string): [string, string][] {
  const declarations: [string, string][] = [];
  for (const [, name, value] of body.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) {
    if (name !== undefined && value !== undefined) {
      declarations.push([name, value.trim().toLowerCase()]);
    }
  }
  return declarations;
}

/**
 * Corps du bloc ouvert par la première `{` après `from`, refermé par
 * appariement d'accolades — un `@media` contient des blocs imbriqués, un
 * `indexOf('}')` s'arrêterait au premier `}` intérieur.
 */
function blockAfter(source: string, from: number): { body: string; end: number } {
  const open = source.indexOf('{', from);
  if (open < 0) {
    throw new Error('Bloc attendu dans globals.css : aucune accolade ouvrante');
  }
  let depth = 0;
  for (let index = open; index < source.length; index += 1) {
    if (source[index] === '{') {
      depth += 1;
    } else if (source[index] === '}') {
      depth -= 1;
      if (depth === 0) {
        return { body: source.slice(open + 1, index), end: index + 1 };
      }
    }
  }
  throw new Error('Bloc non refermé dans globals.css');
}

/**
 * TOUS les blocs `:root` d'un fragment, fusionnés dans l'ordre du document.
 * `redéfinies` liste les variables déclarées plus d'une fois : la dernière
 * gagne — c'est la règle du navigateur, donc celle qu'on vérifie — mais une
 * palette recopiée à la main n'a aucune raison de se contredire.
 */
function rootVariables(fragment: string): {
  declared: Record<string, string>;
  redefined: string[];
} {
  const bodies = [...fragment.matchAll(/:root[^{]*\{([^}]*)\}/g)]
    .map(([, body]) => body)
    .filter((body): body is string => body !== undefined);
  if (bodies.length === 0) {
    throw new Error('Aucun bloc `:root` trouvé dans ce fragment de globals.css');
  }
  const declared: Record<string, string> = {};
  const redefined = new Set<string>();
  for (const body of bodies) {
    for (const [name, value] of declarationsOf(body)) {
      if (name in declared) {
        redefined.add(name);
      }
      declared[name] = value;
    }
  }
  return { declared, redefined: [...redefined].sort() };
}

const DARK_MEDIA = '@media (prefers-color-scheme: dark)';
const darkAt = css.indexOf(DARK_MEDIA);
if (darkAt < 0) {
  throw new Error(`globals.css ne contient plus de bloc « ${DARK_MEDIA} »`);
}
if (css.indexOf(DARK_MEDIA, darkAt + 1) >= 0) {
  throw new Error(
    `globals.css contient plusieurs blocs « ${DARK_MEDIA} » : ce test n'en lit qu'un`,
  );
}

const dark = blockAfter(css, darkAt);
/** Le clair, c'est TOUT le reste du fichier — y compris après le bloc sombre. */
const lightSource = css.slice(0, darkAt) + css.slice(dark.end);

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
  { theme: 'clair', expected: LIGHT, ...rootVariables(lightSource) },
  { theme: 'sombre', expected: DARK, ...rootVariables(dark.body) },
])('globals.css — palette $theme fidèle à tokens.json', ({ expected, declared, redefined }) => {
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

  it('ne redéclare aucune variable dans un second bloc `:root`', () => {
    expect(redefined).toEqual([]);
  });
});

/**
 * `@theme inline` est ce que Tailwind lit pour fabriquer `bg-primary`,
 * `text-muted`, etc. Une couleur écrite là serait invisible aux contrôles
 * ci-dessus tout en s'affichant à l'écran : chaque entrée doit donc se borner
 * à republier la variable `:root` de même nom.
 */
describe('globals.css — `@theme inline` ne fait que republier `:root`', () => {
  const themeAt = css.indexOf('@theme inline');
  if (themeAt < 0) {
    throw new Error('globals.css ne contient plus de bloc `@theme inline`');
  }
  const themeDeclarations = declarationsOf(blockAfter(css, themeAt).body);

  it('couvre exactement les variables de la palette claire', () => {
    expect(themeDeclarations.map(([name]) => name).sort()).toEqual(
      Object.keys(LIGHT)
        .map((variable) => variable.replace(/^--/, '--color-'))
        .sort(),
    );
  });

  for (const [name, value] of themeDeclarations) {
    it(`${name} pointe vers une variable, jamais vers une couleur`, () => {
      expect(`${name}: ${value}`).toBe(`${name}: var(${name.replace(/^--color-/, '--')})`);
    });
  }
});

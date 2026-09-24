import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { describe, expect, it } from 'vitest';

/**
 * LES PAIRES TEXTE / FOND DE L'ADMIN TIENNENT AA, dans les deux thèmes.
 *
 * `globals-tokens.test.ts` vérifie que `globals.css` recopie fidèlement les
 * jetons ; il ne dit rien de ce que ces couleurs donnent l'une sur l'autre.
 * L'audit de septembre 2026 a trouvé, avec des valeurs toutes fidèles : le
 * rouge d'erreur à 3,61:1 sur le fond clair, le violet des liens à 3,78:1
 * sur les surfaces sombres, le gris secondaire à 4,04:1, du blanc à 3,76:1
 * sur les boutons de suppression, et l'orange « Premium » à 2,36:1.
 *
 * Ce fichier mesure donc chaque paire RÉELLEMENT employée par les écrans,
 * avec les valeurs lues dans `globals.css` — clair, puis sombre — et un
 * balai refuse les classes qui la contourneraient (une encre qui ne suit
 * pas le thème, un orange écrit comme du texte).
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

const adminRoot = join(findRepoRoot(), 'apps/admin');
const css = readFileSync(join(adminRoot, 'src/app/globals.css'), 'utf8').replace(
  /\/\*[\s\S]*?\*\//g,
  '',
);

/** Les variables `--x: #rrggbb;` d'un fragment, dans l'ordre (la dernière gagne). */
function variables(fragment: string): Record<string, string> {
  const found: Record<string, string> = {};
  for (const [, name, value] of fragment.matchAll(/(--[\w-]+)\s*:\s*(#[0-9a-fA-F]{6})\s*;/g)) {
    if (name !== undefined && value !== undefined) {
      found[name] = value.toLowerCase();
    }
  }
  return found;
}

const darkAt = css.indexOf('@media (prefers-color-scheme: dark)');
if (darkAt < 0) {
  throw new Error('globals.css ne contient plus de bloc sombre');
}
const light = variables(css.slice(0, darkAt));
const dark = { ...light, ...variables(css.slice(darkAt)) };

type Rgb = readonly [number, number, number];

function rgb(hex: string): Rgb {
  const value = Number.parseInt(hex.slice(1), 16);
  return [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}

/** Une couleur posée à `alpha` sur un fond opaque (ce que peint `bg-x/10`). */
function over(top: Rgb, alpha: number, below: Rgb): Rgb {
  const mix = (i: 0 | 1 | 2): number => top[i] * alpha + below[i] * (1 - alpha);
  return [mix(0), mix(1), mix(2)];
}

/** Luminance relative et rapport de contraste WCAG 2.2. */
function luminance(color: Rgb): number {
  const channel = (value: number): number => {
    const unit = value / 255;
    return unit <= 0.03928 ? unit / 12.92 : ((unit + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(color[0]) + 0.7152 * channel(color[1]) + 0.0722 * channel(color[2]);
}

function contrast(a: Rgb, b: Rgb): number {
  const first = luminance(a);
  const second = luminance(b);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

const WHITE: Rgb = [255, 255, 255];
const BLACK: Rgb = [0, 0, 0];
const TEXT = 4.5;

/** Les paires d'un thème : ce qui s'écrit, où, et sur quoi. */
function pairsOf(palette: Record<string, string>): [string, Rgb, Rgb][] {
  const v = (name: string): Rgb => {
    const hex = palette[name];
    if (hex === undefined) {
      throw new Error(`Variable absente de globals.css : ${name}`);
    }
    return rgb(hex);
  };
  const page = v('--background');
  const surface = v('--surface');
  return [
    ['texte courant sur la page', v('--foreground'), page],
    ['texte courant sur une carte', v('--foreground'), surface],
    ['text-muted sur la page', v('--muted'), page],
    ['text-muted sur une carte', v('--muted'), surface],
    ['text-muted sur bg-black/5 (« Masqué »)', v('--muted'), over(BLACK, 0.05, surface)],
    ['text-muted au survol bg-black/10', v('--muted'), over(BLACK, 0.1, surface)],
    ['indicatif (::placeholder) sur la page', v('--muted'), page],
    ['text-primary-ink sur la page', v('--primary-ink'), page],
    ['text-primary-ink sur une carte', v('--primary-ink'), surface],
    [
      'text-primary-ink sur bg-primary/10 (« Publié », survol fantôme)',
      v('--primary-ink'),
      over(v('--primary'), 0.1, surface),
    ],
    ['text-danger-ink sur la page', v('--danger-ink'), page],
    ['text-danger-ink sur une carte', v('--danger-ink'), surface],
    ['blanc sur bg-primary', WHITE, v('--primary')],
    ['blanc sur bg-primary-dark (survol)', WHITE, v('--primary-dark')],
    ['blanc sur bg-danger-strong', WHITE, v('--danger-strong')],
    ['text-on-accent sur bg-accent (« Premium »)', v('--on-accent'), v('--accent')],
  ];
}

describe.each([
  { theme: 'clair', palette: light },
  { theme: 'sombre', palette: dark },
])('globals.css — thème $theme : chaque paire employée tient AA', ({ palette }) => {
  for (const [what, ink, background] of pairsOf(palette)) {
    it(what, () => {
      expect(contrast(ink, background)).toBeGreaterThanOrEqual(TEXT);
    });
  }
});

/** Les sources des écrans, tests exclus. */
function sources(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) {
      return sources(path);
    }
    return path.endsWith('.tsx') && !path.includes('.test.') ? [path] : [];
  });
}

/**
 * Les classes qui contournent les paires ci-dessus : une encre qui ne suit
 * pas le thème (`text-primary`, `text-danger`), un orange écrit comme un
 * texte, un aplat rouge clair sous du blanc, un survol qui éclaircit le fond
 * sous le libellé.
 */
const FORBIDDEN: [RegExp, string][] = [
  [/(?<![\w-])(?:hover:)?text-(?:primary|danger)(?![\w/-])/, 'encre sans thème : `-ink`'],
  [/(?<![\w-])text-accent(?![\w/-])/, 'orange en texte : 2,59:1 sur blanc'],
  [/(?<![\w-])bg-danger(?![\w/-])[^'"`]*text-white/, 'blanc sur danger : 3,76:1'],
  [/text-white[^'"`]*(?<![\w-])bg-danger(?![\w/-])/, 'blanc sur danger : 3,76:1'],
  [/hover:opacity-/, 'un survol par opacité éclaircit le fond sous le texte'],
];

describe('les écrans n’emploient que des paires mesurées', () => {
  const files = sources(join(adminRoot, 'src'));

  it('trouve des écrans à balayer', () => {
    expect(files.length).toBeGreaterThan(10);
  });

  it('aucune classe ne contourne les paires', () => {
    const faults: string[] = [];
    for (const file of files) {
      readFileSync(file, 'utf8')
        .split('\n')
        .forEach((line, index) => {
          for (const [pattern, why] of FORBIDDEN) {
            if (pattern.test(line)) {
              faults.push(`${file.slice(adminRoot.length + 1)}:${index + 1} — ${why}`);
            }
          }
        });
    }
    expect(faults).toEqual([]);
  });

  it('le balai reconnaît ce qu’il doit, et rien de plus', () => {
    const caught = (line: string) => FORBIDDEN.some(([pattern]) => pattern.test(line));
    expect(caught('className="text-sm text-danger"')).toBe(true);
    expect(caught('className="hover:text-primary"')).toBe(true);
    expect(caught('className="bg-danger px-3 text-white"')).toBe(true);
    expect(caught('className="text-xs text-accent"')).toBe(true);
    expect(caught('className="text-danger-ink hover:text-primary-ink"')).toBe(false);
    expect(caught('className="bg-primary/10 text-primary-ink"')).toBe(false);
    expect(caught('className="bg-danger-strong text-white"')).toBe(false);
    expect(caught("up ? 'bg-success' : 'bg-danger'")).toBe(false);
  });
});

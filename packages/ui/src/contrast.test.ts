import tokens from '@carlys/design-tokens/tokens.json';
import { describe, expect, it } from 'vitest';

import stylesheet from './styles/components.css?raw';

/**
 * LES PAIRES TEXTE / FOND DU DESIGN SYSTEM WEB TIENNENT AA, dans ses trois
 * thèmes (clair, sombre, OLED).
 *
 * La relecture de septembre 2026 y a retrouvé, intactes, des paires déjà
 * corrigées dans l'application et l'admin : l'ambre d'une pastille à 1,83:1
 * sur sa teinte, le violet d'une pastille à 3,86 (clair) et 3,38 (sombre),
 * le libellé d'un bouton secondaire à 3,78 sur une surface sombre, du blanc
 * à 3,76 sur un bouton destructif, le gris « atténué » à 4,04.
 *
 * Chaque paire est donc LUE dans `components.css` — l'encre et le fond de la
 * règle qui les peint, les variables de thème de `.carlys-root`, les valeurs
 * de `tokens.json` —, jamais recopiée : une règle qui change est mesurée
 * telle qu'elle est écrite. Un fond translucide (`color-mix(… transparent)`)
 * se compose sur ce qu'il recouvre : la page, une carte ou la surface
 * alternée.
 */

type Rgb = readonly [number, number, number];

/** Une couleur et son opacité, telle qu'une déclaration la peint. */
interface Paint {
  readonly rgb: Rgb;
  readonly alpha: number;
}

const TEXT = 4.5;
const LARGE_TEXT = 3;
const GRAPHIC = 3;

const css = stylesheet.replace(/\/\*[\s\S]*?\*\//g, '');

/** Les déclarations d'une règle, par son sélecteur exact. */
function rule(selector: string): Record<string, string> {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const body = new RegExp(`^${escaped}\\s*\\{([^}]*)\\}`, 'm').exec(css)?.[1];
  if (body === undefined) {
    throw new Error(`Règle absente de components.css : ${selector}`);
  }
  const declarations: Record<string, string> = {};
  for (const [, name, value] of body.matchAll(/([\w-]+)\s*:\s*([^;]+);/g)) {
    if (name !== undefined && value !== undefined) {
      declarations[name] = value.trim();
    }
  }
  return declarations;
}

/** Une déclaration qui DOIT exister : son absence est une faute du test. */
function declared(selector: string, property: string): string {
  const value = rule(selector)[property];
  if (value === undefined) {
    throw new Error(`${selector} ne déclare plus ${property}`);
  }
  return value;
}

/** Les variables `--carlys-*` que `scripts/build-css.mjs` tire des jetons. */
const tokenVariables: Record<string, string> = {};
for (const [prefix, group] of [
  ['color-', tokens.color.brand],
  ['neutral-', tokens.color.neutral],
  ['color-', tokens.color.semantic],
  ['surface-', tokens.color.surface],
] as const) {
  for (const [name, value] of Object.entries(group)) {
    if (!name.startsWith('$')) {
      tokenVariables[`--carlys-${prefix}${name}`] = value;
    }
  }
}

/** Les variables d'un thème : la racine claire, surchargée s'il le faut. */
function themeVariables(selector?: string): Record<string, string> {
  const own = (declarations: Record<string, string>) =>
    Object.fromEntries(Object.entries(declarations).filter(([name]) => name.startsWith('--')));
  return { ...own(rule('.carlys-root')), ...(selector ? own(rule(selector)) : {}) };
}

function rgb(hex: string): Rgb {
  const value = Number.parseInt(hex.slice(1), 16);
  return [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}

/** Ce qu'une valeur CSS peint, variables résolues dans [theme]. */
function paint(value: string, theme: Record<string, string>): Paint {
  const reference = /^var\((--[\w-]+)\)$/.exec(value)?.[1];
  if (reference !== undefined) {
    const next = theme[reference] ?? tokenVariables[reference];
    if (next === undefined) {
      throw new Error(`Variable inconnue : ${reference}`);
    }
    return paint(next, theme);
  }
  const mix = /^color-mix\(in srgb,\s*(.+?)\s+([\d.]+)%,\s*transparent\)$/.exec(value);
  if (mix?.[1] !== undefined && mix[2] !== undefined) {
    const base = paint(mix[1], theme);
    return { rgb: base.rgb, alpha: (base.alpha * Number(mix[2])) / 100 };
  }
  if (/^#[0-9a-f]{6}$/i.test(value)) {
    return { rgb: rgb(value), alpha: 1 };
  }
  if (value === 'transparent') {
    return { rgb: [0, 0, 0], alpha: 0 };
  }
  throw new Error(`Couleur illisible : ${value}`);
}

/** La couleur que l'œil reçoit : [top] posé sur un fond opaque. */
function onto(top: Paint, below: Rgb): Rgb {
  const mix = (i: 0 | 1 | 2): number => top.rgb[i] * top.alpha + below[i] * (1 - top.alpha);
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

/** Une paire mesurée : ce qui s'écrit, sur quoi, et son seuil. */
type Pair = readonly [what: string, ink: Rgb, ground: Rgb, threshold: number];

/** Les paires d'un thème, lues dans les règles qui les peignent. */
function pairsOf(theme: Record<string, string>): Pair[] {
  const read = (selector: string, property: string): Paint =>
    paint(declared(selector, property), theme);
  const surface = (name: string): Rgb => paint(`var(--carlys-${name})`, theme).rgb;
  // Un texte courant se pose sur la page ou sur une carte ; une pastille et
  // un bouton, aussi sur la surface alternée d'une ligne de liste.
  const pageAndCard: [string, Rgb][] = [
    ['la page', surface('background')],
    ['une carte', surface('surface')],
  ];
  const everywhere: [string, Rgb][] = [
    ...pageAndCard,
    ['la surface alternée', surface('surface-alt')],
  ];
  const pairs: Pair[] = [];

  /** Une encre posée sur un fond (opaque ou non) posé sur chaque support. */
  const measure = (
    what: string,
    ink: Paint,
    fill: Paint | null,
    threshold: number,
    supports = pageAndCard,
  ) => {
    for (const [where, below] of supports) {
      const ground = fill === null ? below : onto(fill, below);
      pairs.push([`${what}, sur ${where}`, onto(ink, ground), ground, threshold]);
    }
  };

  for (const variant of ['neutral', 'primary', 'accent', 'warning']) {
    const selector = `.carlys-badge--${variant}`;
    measure(
      `pastille ${variant}`,
      read(selector, 'color'),
      read(selector, 'background'),
      TEXT,
      everywhere,
    );
  }

  for (const variant of ['primary', 'secondary', 'ghost', 'destructive']) {
    const selector = `.carlys-button--${variant}`;
    const fill = read(selector, 'background');
    const ink = read(selector, 'color');
    measure(`bouton ${variant}`, ink, fill.alpha === 0 ? null : fill, TEXT, everywhere);
    const hover = rule(`${selector}:hover:not(:disabled)`).background;
    if (hover !== undefined) {
      measure(`bouton ${variant} au survol`, ink, paint(hover, theme), TEXT, everywhere);
    }
  }

  const muted = paint('var(--carlys-text-muted)', theme);
  measure('texte atténué', muted, null, TEXT);
  measure('texte courant', paint('var(--carlys-text)', theme), null, TEXT);
  measure('erreur de champ', read('.carlys-field__error', 'color'), null, TEXT);
  const field = read('.carlys-field__input', 'background');
  measure('saisie de champ', read('.carlys-field__input', 'color'), field, TEXT);
  measure('indicatif de champ', read('.carlys-field__input::placeholder', 'color'), field, TEXT);
  // 40 points : un GRAND texte, au seuil de 3:1.
  measure(
    'grande métrique',
    read('.carlys-metric--lg .carlys-metric__value', 'color'),
    null,
    LARGE_TEXT,
  );
  measure(
    "icône d'erreur",
    read('.carlys-state--error .carlys-state__icon', 'color'),
    null,
    GRAPHIC,
  );
  measure("icône d'état", read('.carlys-state__icon', 'color'), null, GRAPHIC);
  measure('indicateur de chargement', read('.carlys-spinner', 'border-top-color'), null, GRAPHIC);
  return pairs;
}

describe.each([
  { theme: 'clair', variables: themeVariables() },
  { theme: 'sombre', variables: themeVariables(".carlys-root[data-carlys-theme='dark']") },
  { theme: 'OLED', variables: themeVariables(".carlys-root[data-carlys-theme='oled']") },
])('components.css — thème $theme : chaque paire tient son seuil', ({ variables }) => {
  const pairs = pairsOf(variables);

  it('mesure des paires', () => {
    expect(pairs.length).toBeGreaterThan(40);
  });

  it.each(pairs.map((pair) => [pair[0], pair] as const))('%s', (_what, pair) => {
    const [, ink, ground, threshold] = pair;
    expect(contrast(ink, ground)).toBeGreaterThanOrEqual(threshold);
  });
});

describe('le bouton destructif', () => {
  it('se remplit du rouge profond, et son survol ne peut que le foncer', () => {
    expect(declared('.carlys-button--destructive', 'background')).toBe(
      'var(--carlys-color-dangerStrong)',
    );
    const factor = /^brightness\(([\d.]+)\)$/.exec(
      declared('.carlys-button--destructive:hover:not(:disabled)', 'filter'),
    )?.[1];
    expect(Number(factor)).toBeLessThan(1);
  });
});

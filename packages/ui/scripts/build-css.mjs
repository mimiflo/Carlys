// Génère dist/tokens.css depuis tokens.json (source de vérité), copie les
// styles de composants et assemble dist/styles.css — exécuté par `pnpm build`.
import { mkdirSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const tokens = JSON.parse(
  readFileSync(join(root, '..', 'design-tokens', 'src', 'tokens.json'), 'utf8'),
);

// Les clés `$comment-…`/`$description` documentent tokens.json ; elles ne
// sont pas des valeurs et n'ont rien à faire dans le CSS généré.
const entries = (record) => Object.entries(record).filter(([name]) => !name.startsWith('$'));

const px = (value) => `${value}px`;
const cubic = ([x1, y1, x2, y2]) => `cubic-bezier(${x1}, ${y1}, ${x2}, ${y2})`;
const shadow = ({ y, blur, opacity }) => `0 ${y}px ${blur}px rgba(11, 11, 24, ${opacity})`;

const lines = [
  '/* GÉNÉRÉ depuis packages/design-tokens/src/tokens.json — ne pas éditer. */',
  ':root {',
];

for (const [name, value] of entries(tokens.color.brand)) {
  lines.push(`  --carlys-color-${name}: ${value};`);
}
for (const [name, value] of entries(tokens.color.neutral)) {
  lines.push(`  --carlys-neutral-${name}: ${value};`);
}
for (const [name, value] of entries(tokens.color.semantic)) {
  lines.push(`  --carlys-color-${name}: ${value};`);
}
for (const [name, value] of entries(tokens.color.surface)) {
  lines.push(`  --carlys-surface-${name}: ${value};`);
}
for (const [name, { colors, stops }] of entries(tokens.color.gradient)) {
  const halts = colors.map((color, index) => `${color} ${stops[index] * 100}%`).join(', ');
  lines.push(`  --carlys-gradient-${name}: linear-gradient(90deg, ${halts});`);
}
for (const [name, value] of entries(tokens.spacing)) {
  lines.push(`  --carlys-spacing-${name}: ${px(value)};`);
}
for (const [name, value] of entries(tokens.radius)) {
  lines.push(`  --carlys-radius-${name}: ${px(value)};`);
}
for (const [name, value] of entries(tokens.typography.fontFamily)) {
  const stack =
    name === 'mono'
      ? `'${value}', ui-monospace, SFMono-Regular, monospace`
      : `'${value}', system-ui, -apple-system, 'Segoe UI', sans-serif`;
  lines.push(`  --carlys-font-${name}: ${stack};`);
}
for (const [name, value] of entries(tokens.typography.size)) {
  lines.push(`  --carlys-text-${name}: ${px(value)};`);
}
for (const [name, value] of entries(tokens.typography.weight)) {
  lines.push(`  --carlys-weight-${name}: ${value};`);
}
for (const [name, value] of entries(tokens.typography.lineHeight)) {
  lines.push(`  --carlys-leading-${name}: ${value};`);
}
for (const [name, value] of entries(tokens.shadow)) {
  lines.push(`  --carlys-shadow-${name}: ${shadow(value)};`);
}
for (const [name, value] of entries(tokens.motion.duration)) {
  lines.push(`  --carlys-duration-${name}: ${value}ms;`);
}
for (const [name, value] of entries(tokens.motion.easing)) {
  lines.push(`  --carlys-easing-${name}: ${cubic(value)};`);
}
lines.push('}', '');

mkdirSync(join(root, 'dist'), { recursive: true });
writeFileSync(join(root, 'dist', 'tokens.css'), lines.join('\n'));
copyFileSync(join(root, 'src', 'styles', 'components.css'), join(root, 'dist', 'components.css'));
writeFileSync(
  join(root, 'dist', 'styles.css'),
  ["@import './tokens.css';", "@import './components.css';", ''].join('\n'),
);
// Variante aplatie (un seul fichier) pour les outils qui ne suivent pas
// les @import — même contenu que styles.css.
writeFileSync(
  join(root, 'dist', 'carlys-ui.css'),
  [lines.join('\n'), readFileSync(join(root, 'src', 'styles', 'components.css'), 'utf8')].join(
    '\n',
  ),
);
console.log('dist/styles.css et dist/carlys-ui.css assemblés depuis tokens.json');

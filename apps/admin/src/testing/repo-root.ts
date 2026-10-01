import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

/**
 * Racine du dépôt, trouvée en remontant jusqu'au marqueur de l'espace de
 * travail : `import.meta.url` n'est pas une URL `file:` sous jsdom, et le
 * répertoire courant dépend de l'endroit d'où la suite est lancée.
 */
export function findRepoRoot(): string {
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

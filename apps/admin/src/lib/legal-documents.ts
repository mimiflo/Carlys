import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { parseMarkdown, type MarkdownBlock } from './markdown';

export type LegalDocumentSlug = 'privacy' | 'terms';

/**
 * Les textes légaux vivent dans `docs/legal/`, à la racine du dépôt : une
 * seule source, relue par une personne comme par le build. Ils sont lus au
 * BUILD (pages statiques), jamais à la requête : le conteneur n'a pas besoin
 * du dossier, seul le contexte de build l'a (voir apps/admin/Dockerfile).
 *
 * `process.cwd()` est `apps/admin` dans tous les cas connus : `next build`,
 * `next dev` et `vitest` lancés par pnpm depuis le paquet.
 */
const LEGAL_DIRECTORY = path.resolve(process.cwd(), '..', '..', 'docs', 'legal');

export async function readLegalDocument(slug: LegalDocumentSlug): Promise<MarkdownBlock[]> {
  const file = path.join(LEGAL_DIRECTORY, `${slug}.md`);
  let source: string;
  try {
    source = await readFile(file, 'utf8');
  } catch (cause) {
    throw new Error(
      `Document légal introuvable : ${file}. Le dossier docs/legal doit exister au moment du build.`,
      { cause },
    );
  }
  return parseMarkdown(source);
}

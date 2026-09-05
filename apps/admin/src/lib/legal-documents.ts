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

/** Marqueur laissé par la rédaction : `[À COMPLÉTER : ce qui manque]`. */
const PLACEHOLDER = /\[À COMPLÉTER\s*:[^\]]*\]/gu;

/** Les marqueurs encore présents, sans doublon, dans l'ordre d'apparition. */
export function findPlaceholders(source: string): string[] {
  const found = (source.match(PLACEHOLDER) ?? []).map((marker) => marker.replace(/\s+/gu, ' '));
  return [...new Set(found)];
}

/**
 * Garde-fou : un texte légal inachevé ne doit jamais atteindre les
 * utilisateurs. `next build` tourne toujours avec NODE_ENV=production, en CI
 * comme dans l'image Docker, donc NODE_ENV seul ne distingue pas une
 * vérification d'un déploiement : l'image de production (apps/admin/Dockerfile)
 * déclare en plus LEGAL_PLACEHOLDERS=forbid, et c'est elle que le build
 * refuse. Tout autre build de production signale les marqueurs dans sa sortie
 * sans bloquer, et `next dev` rend le texte tel quel pour la relecture.
 */
export function parseLegalDocument(slug: LegalDocumentSlug, source: string): MarkdownBlock[] {
  const placeholders = findPlaceholders(source);
  if (placeholders.length > 0 && process.env.NODE_ENV === 'production') {
    const inventory = placeholders.map((marker) => `  - ${marker}`).join('\n');
    if (process.env.LEGAL_PLACEHOLDERS === 'forbid') {
      throw new Error(
        `docs/legal/${slug}.md contient encore ${placeholders.length} marqueur(s) à compléter ; ` +
          `une image de production ne peut pas les servir :\n${inventory}\n` +
          'Renseigne-les, ou construis une image de recette avec --build-arg LEGAL_PLACEHOLDERS=allow.',
      );
    }
    console.warn(
      `docs/legal/${slug}.md : ${placeholders.length} marqueur(s) à compléter avant toute mise en production :\n${inventory}`,
    );
  }
  return parseMarkdown(source);
}

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
  return parseLegalDocument(slug, source);
}

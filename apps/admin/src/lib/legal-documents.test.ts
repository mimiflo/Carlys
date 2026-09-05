import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  findPlaceholders,
  parseLegalDocument,
  readLegalDocument,
  type LegalDocumentSlug,
} from './legal-documents';
import { parseMarkdown, type InlineNode, type MarkdownBlock } from './markdown';

const SLUGS: readonly LegalDocumentSlug[] = ['privacy', 'terms'];

/**
 * Le lecteur Markdown ne connaît que titres, listes, gras et liens : code,
 * tableau, citation, emphase à une étoile ou lien mal fermé resteraient dans
 * un nœud texte et s'afficheraient tels quels aux utilisateurs.
 */
const IGNORED_SYNTAX = /[`*|]|\]\(|^>/u;

const UNFINISHED = [
  '# Titre',
  '',
  'Éditeur : [À COMPLÉTER : raison sociale], siège [À COMPLÉTER : adresse postale',
  'du responsable]. Contact : [À COMPLÉTER : raison sociale].',
].join('\n');

/** Toutes les valeurs des nœuds texte, quelle que soit leur profondeur. */
function textNodes(blocks: readonly MarkdownBlock[]): string[] {
  const values: string[] = [];
  const visit = (nodes: readonly InlineNode[]) => {
    for (const node of nodes) {
      if (node.type === 'text') {
        values.push(node.value);
      } else {
        visit(node.children);
      }
    }
  };
  for (const block of blocks) {
    if (block.type === 'list') {
      block.items.forEach(visit);
    } else {
      visit(block.children);
    }
  }
  return values;
}

/** Les nœuds texte qui trahissent une syntaxe non prise en charge. */
function residueOf(blocks: readonly MarkdownBlock[]): string[] {
  return textNodes(blocks).filter((value) => IGNORED_SYNTAX.test(value));
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.restoreAllMocks();
});

describe('findPlaceholders', () => {
  it('relève chaque marqueur une seule fois, même coupé par un retour à la ligne', () => {
    expect(findPlaceholders(UNFINISHED)).toEqual([
      '[À COMPLÉTER : raison sociale]',
      '[À COMPLÉTER : adresse postale du responsable]',
    ]);
  });

  it('ne confond pas un lien ou un crochet ordinaire avec un marqueur', () => {
    expect(findPlaceholders('Vois [la politique](/privacy) et [1].')).toEqual([]);
  });
});

describe('parseLegalDocument', () => {
  it('refuse le build de l’image de production tant qu’un marqueur subsiste', () => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('LEGAL_PLACEHOLDERS', 'forbid');

    expect(() => parseLegalDocument('privacy', UNFINISHED)).toThrow(
      /docs\/legal\/privacy\.md contient encore 2 marqueur/,
    );
    expect(() => parseLegalDocument('privacy', UNFINISHED)).toThrow(
      '[À COMPLÉTER : adresse postale du responsable]',
    );
  });

  it('laisse passer l’image de production dès que le texte est complet', () => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('LEGAL_PLACEHOLDERS', 'forbid');
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    expect(parseLegalDocument('terms', '# Titre\n\nTexte complet.')).toHaveLength(2);
    expect(warn).not.toHaveBeenCalled();
  });

  it('signale les marqueurs sans bloquer un build de production ordinaire (CI, poste)', () => {
    vi.stubEnv('NODE_ENV', 'production');
    vi.stubEnv('LEGAL_PLACEHOLDERS', '');
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    const blocks = parseLegalDocument('terms', UNFINISHED);

    expect(blocks.map((block) => block.type)).toEqual(['heading', 'paragraph']);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn.mock.calls[0]?.[0]).toMatch(/docs\/legal\/terms\.md : 2 marqueur/);
    expect(warn.mock.calls[0]?.[0]).toContain('[À COMPLÉTER : raison sociale]');
  });

  it('rend le texte tel quel en développement, même avec l’interdiction posée', () => {
    vi.stubEnv('NODE_ENV', 'development');
    vi.stubEnv('LEGAL_PLACEHOLDERS', 'forbid');
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    const blocks = parseLegalDocument('privacy', UNFINISHED);

    expect(textNodes(blocks).join(' ')).toContain('[À COMPLÉTER : raison sociale]');
    expect(warn).not.toHaveBeenCalled();
  });
});

describe('Les vrais fichiers de docs/legal', () => {
  it.each(SLUGS)('%s.md se lit et se parse sans erreur', async (slug) => {
    const blocks = await readLegalDocument(slug);

    expect(blocks[0]).toMatchObject({ type: 'heading', level: 1 });
  });

  it('le filet détecte bien code, emphase à une étoile, tableau, citation et lien mal fermé', () => {
    const blocks = parseMarkdown(
      [
        'Du `code`, de l’*italique* et **du gras** accepté.',
        '',
        '| colonne | colonne |',
        '',
        '> une citation',
        '',
        'Un [lien](mal fermé',
        '',
        'Un paragraphe sain, avec un [À COMPLÉTER : marqueur] et un [lien](/ok).',
      ].join('\n'),
    );

    expect(residueOf(blocks)).toEqual([
      'Du `code`, de l’*italique* et ',
      '| colonne | colonne |',
      '> une citation',
      'Un [lien](mal fermé',
    ]);
  });

  it.each(SLUGS)('%s.md n’emploie aucune syntaxe que le lecteur ignorerait', async (slug) => {
    expect(residueOf(await readLegalDocument(slug))).toEqual([]);
  });
});

import { describe, expect, it } from 'vitest';
import { parseInline, parseMarkdown } from './markdown';

describe('parseMarkdown', () => {
  it('distingue titres, paragraphes et listes séparés par des lignes vides', () => {
    const blocks = parseMarkdown(
      [
        '# Titre',
        '',
        'Un paragraphe',
        'sur deux lignes.',
        '',
        '## Sous-titre',
        '',
        '- premier',
        '- second',
        '',
        '1. un',
        '2. deux',
      ].join('\n'),
    );

    expect(blocks).toEqual([
      { type: 'heading', level: 1, children: [{ type: 'text', value: 'Titre' }] },
      { type: 'paragraph', children: [{ type: 'text', value: 'Un paragraphe sur deux lignes.' }] },
      { type: 'heading', level: 2, children: [{ type: 'text', value: 'Sous-titre' }] },
      {
        type: 'list',
        ordered: false,
        items: [[{ type: 'text', value: 'premier' }], [{ type: 'text', value: 'second' }]],
      },
      {
        type: 'list',
        ordered: true,
        items: [[{ type: 'text', value: 'un' }], [{ type: 'text', value: 'deux' }]],
      },
    ]);
  });

  it('rattache une ligne indentée à l’élément de liste précédent', () => {
    const blocks = parseMarkdown(['- un élément', '  qui continue', '- un autre'].join('\n'));

    expect(blocks).toEqual([
      {
        type: 'list',
        ordered: false,
        items: [
          [{ type: 'text', value: 'un élément qui continue' }],
          [{ type: 'text', value: 'un autre' }],
        ],
      },
    ]);
  });

  it('coupe une liste quand un paragraphe la suit sans ligne vide', () => {
    const blocks = parseMarkdown(['- un', 'Texte après.'].join('\n'));

    expect(blocks.map((block) => block.type)).toEqual(['list', 'paragraph']);
  });
});

describe('parseInline', () => {
  it('reconnaît le gras et les liens, le reste est du texte', () => {
    expect(parseInline('Vois **ceci** et [là](https://carlys.test/x).')).toEqual([
      { type: 'text', value: 'Vois ' },
      { type: 'strong', children: [{ type: 'text', value: 'ceci' }] },
      { type: 'text', value: ' et ' },
      { type: 'link', href: 'https://carlys.test/x', children: [{ type: 'text', value: 'là' }] },
      { type: 'text', value: '.' },
    ]);
  });

  it('laisse un marqueur [À COMPLÉTER : …] tel quel : ce n’est pas un lien', () => {
    expect(parseInline('Éditeur : [À COMPLÉTER : raison sociale].')).toEqual([
      { type: 'text', value: 'Éditeur : [À COMPLÉTER : raison sociale].' },
    ]);
  });
});

/**
 * Lecteur Markdown MINIMAL pour les textes légaux du dépôt (docs/legal).
 *
 * Il ne couvre que ce que ces documents emploient : titres (`#` à `###`),
 * paragraphes, listes à puces et numérotées, gras (`**…**`) et liens
 * (`[texte](url)`). Le résultat est un arbre rendu en éléments React,
 * jamais du HTML injecté : aucune bibliothèque n'est nécessaire, et rien
 * ne peut y glisser de script.
 */

export type InlineNode =
  | { readonly type: 'text'; readonly value: string }
  | { readonly type: 'strong'; readonly children: readonly InlineNode[] }
  | { readonly type: 'link'; readonly href: string; readonly children: readonly InlineNode[] };

export type MarkdownBlock =
  | {
      readonly type: 'heading';
      readonly level: 1 | 2 | 3;
      readonly children: readonly InlineNode[];
    }
  | { readonly type: 'paragraph'; readonly children: readonly InlineNode[] }
  | {
      readonly type: 'list';
      readonly ordered: boolean;
      readonly items: readonly (readonly InlineNode[])[];
    };

const HEADING = /^(#{1,3})\s+(.*)$/;
const UNORDERED_ITEM = /^[-*]\s+(.*)$/;
const ORDERED_ITEM = /^\d+[.)]\s+(.*)$/;
/** Gras ou lien, le premier qui vient. */
const INLINE = /\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)/;

export function parseInline(source: string): InlineNode[] {
  const nodes: InlineNode[] = [];
  let rest = source;
  for (;;) {
    const match = INLINE.exec(rest);
    if (match === null) {
      break;
    }
    if (match.index > 0) {
      nodes.push({ type: 'text', value: rest.slice(0, match.index) });
    }
    const [whole, strong, linkText, href] = match;
    if (strong !== undefined) {
      nodes.push({ type: 'strong', children: parseInline(strong) });
    } else if (linkText !== undefined && href !== undefined) {
      nodes.push({ type: 'link', href, children: parseInline(linkText) });
    }
    rest = rest.slice(match.index + whole.length);
  }
  if (rest !== '') {
    nodes.push({ type: 'text', value: rest });
  }
  return nodes;
}

export function parseMarkdown(source: string): MarkdownBlock[] {
  const blocks: MarkdownBlock[] = [];
  let paragraph: string[] = [];
  let list: { ordered: boolean; items: string[] } | null = null;

  const flushParagraph = () => {
    if (paragraph.length > 0) {
      blocks.push({ type: 'paragraph', children: parseInline(paragraph.join(' ')) });
      paragraph = [];
    }
  };
  const flushList = () => {
    if (list !== null) {
      blocks.push({
        type: 'list',
        ordered: list.ordered,
        items: list.items.map((item) => parseInline(item)),
      });
      list = null;
    }
  };

  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trimEnd();
    if (line.trim() === '') {
      flushParagraph();
      flushList();
      continue;
    }

    const heading = HEADING.exec(line);
    if (heading !== null && heading[1] !== undefined && heading[2] !== undefined) {
      flushParagraph();
      flushList();
      blocks.push({
        type: 'heading',
        level: heading[1].length as 1 | 2 | 3,
        children: parseInline(heading[2].trim()),
      });
      continue;
    }

    const unordered = UNORDERED_ITEM.exec(line);
    const ordered = unordered === null ? ORDERED_ITEM.exec(line) : null;
    const item = unordered?.[1] ?? ordered?.[1];
    if (item !== undefined) {
      flushParagraph();
      const isOrdered = ordered !== null;
      if (list === null || list.ordered !== isOrdered) {
        flushList();
        list = { ordered: isOrdered, items: [] };
      }
      list.items.push(item.trim());
      continue;
    }

    if (list !== null && /^\s+/.test(rawLine)) {
      // Ligne de continuation d'un élément de liste (indentée).
      const last = list.items.length - 1;
      list.items[last] = `${list.items[last] ?? ''} ${line.trim()}`;
      continue;
    }

    flushList();
    paragraph.push(line.trim());
  }

  flushParagraph();
  flushList();
  return blocks;
}

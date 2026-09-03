import type { ReactNode } from 'react';
import type { InlineNode, MarkdownBlock } from '@/lib/markdown';

const HEADING_CLASSES: Record<1 | 2 | 3, string> = {
  1: 'text-2xl font-bold tracking-tight',
  2: 'mt-8 text-lg font-semibold',
  3: 'mt-6 text-base font-semibold',
};

function renderInline(nodes: readonly InlineNode[]): ReactNode[] {
  return nodes.map((node, index) => {
    switch (node.type) {
      case 'text':
        return node.value;
      case 'strong':
        return (
          <strong key={index} className="font-semibold">
            {renderInline(node.children)}
          </strong>
        );
      case 'link':
        return (
          <a key={index} href={node.href} className="text-primary underline">
            {renderInline(node.children)}
          </a>
        );
    }
  });
}

/** Rend l'arbre produit par `parseMarkdown` : éléments React, jamais de HTML brut. */
export function MarkdownDocument({ blocks }: { blocks: readonly MarkdownBlock[] }) {
  return (
    <div className="flex flex-col gap-4 leading-relaxed">
      {blocks.map((block, index) => {
        switch (block.type) {
          case 'heading': {
            const Tag = `h${block.level}` as const;
            return (
              <Tag key={index} className={HEADING_CLASSES[block.level]}>
                {renderInline(block.children)}
              </Tag>
            );
          }
          case 'paragraph':
            return <p key={index}>{renderInline(block.children)}</p>;
          case 'list': {
            const Tag = block.ordered ? 'ol' : 'ul';
            return (
              <Tag
                key={index}
                className={`flex flex-col gap-1 pl-6 ${block.ordered ? 'list-decimal' : 'list-disc'}`}
              >
                {block.items.map((item, itemIndex) => (
                  <li key={itemIndex}>{renderInline(item)}</li>
                ))}
              </Tag>
            );
          }
        }
      })}
    </div>
  );
}

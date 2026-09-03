import type { Metadata } from 'next';
import { MarkdownDocument } from '@/components/markdown-document';
import { PublicCard } from '@/components/public-page';
import { readLegalDocument } from '@/lib/legal-documents';

export const metadata: Metadata = {
  title: 'Conditions d’utilisation · Carlys',
};

/** Rendue au build depuis docs/legal/terms.md : la page ne lit rien à la requête. */
export const dynamic = 'force-static';

export default async function TermsPage() {
  const blocks = await readLegalDocument('terms');
  return (
    <PublicCard>
      <MarkdownDocument blocks={blocks} />
    </PublicCard>
  );
}

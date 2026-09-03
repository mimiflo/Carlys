import type { Metadata } from 'next';
import { MarkdownDocument } from '@/components/markdown-document';
import { PublicCard } from '@/components/public-page';
import { readLegalDocument } from '@/lib/legal-documents';

export const metadata: Metadata = {
  title: 'Politique de confidentialité · Carlys',
};

/** Rendue au build depuis docs/legal/privacy.md : la page ne lit rien à la requête. */
export const dynamic = 'force-static';

export default async function PrivacyPage() {
  const blocks = await readLegalDocument('privacy');
  return (
    <PublicCard>
      <MarkdownDocument blocks={blocks} />
    </PublicCard>
  );
}

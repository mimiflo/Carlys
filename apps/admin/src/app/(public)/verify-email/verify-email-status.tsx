'use client';

import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import { PublicNotice } from '@/components/public-page';
import { isNetworkFailure, publicApi, publicFailureMessage } from '@/lib/public-api';

const FAILURE_BY_STATUS = {
  401: 'Ce lien n’est plus valable : il a déjà servi ou il a expiré. Demande un nouvel e-mail de vérification depuis l’application.',
} as const;

/**
 * Vérifie l'adresse dès l'ouverture du lien. L'appel passe par une requête
 * TanStack plutôt qu'un effet : une seule exécution par jeton même quand
 * React monte deux fois le composant, et aucune nouvelle tentative
 * automatique, car un jeton est à usage unique.
 */
export function VerifyEmailStatus() {
  const token = useSearchParams().get('token');
  const hasToken = token !== null && token !== '';

  const verification = useQuery({
    queryKey: ['public', 'verify-email', token],
    queryFn: async () => {
      await publicApi.verifyEmail(token ?? '');
      return true;
    },
    enabled: hasToken,
    retry: false,
    staleTime: Number.POSITIVE_INFINITY,
  });

  if (!hasToken) {
    return (
      <PublicNotice tone="error">
        Ce lien est incomplet. Ouvre l’e-mail que tu as reçu et clique de nouveau sur son lien, ou
        demande un nouvel e-mail depuis l’application.
      </PublicNotice>
    );
  }

  if (verification.isPending) {
    return (
      <p role="status" className="text-muted">
        Vérification en cours…
      </p>
    );
  }

  if (verification.isError) {
    return (
      <>
        <PublicNotice tone="error">
          {publicFailureMessage(verification.error, FAILURE_BY_STATUS)}
        </PublicNotice>
        {isNetworkFailure(verification.error) && (
          <button
            type="button"
            onClick={() => void verification.refetch()}
            className="self-start rounded-lg border border-primary px-4 py-2 text-sm font-semibold text-primary transition-colors hover:bg-primary hover:text-white"
          >
            Réessayer
          </button>
        )}
      </>
    );
  }

  return (
    <PublicNotice tone="success">
      Ton adresse e-mail est vérifiée. Tu peux retourner dans l’application.
    </PublicNotice>
  );
}

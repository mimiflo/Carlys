import { ApiError, isNetworkFailure, requestJson } from './api-transport';

/**
 * Appels des pages PUBLIQUES, celles qu'un e-mail ouvre dans un navigateur.
 *
 * Aucun jeton n'est jamais envoyé : ces routes sont publiques côté API, et
 * un jeton d'administration qui traînerait dans l'onglet n'a rien à faire
 * dans une requête déclenchée par un lien reçu par e-mail.
 */
export const publicApi = {
  /** Consomme le jeton du lien de réinitialisation ; l'API répond 204. */
  async resetPassword(token: string, newPassword: string): Promise<void> {
    await requestJson(
      '/auth/reset-password',
      { method: 'POST', body: JSON.stringify({ token, newPassword }) },
      null,
    );
  },

  /** Consomme le jeton du lien de vérification d'adresse ; l'API répond 204. */
  async verifyEmail(token: string): Promise<void> {
    await requestJson(
      '/auth/verify-email',
      { method: 'POST', body: JSON.stringify({ token }) },
      null,
    );
  },
};

export const NETWORK_FAILURE_MESSAGE =
  'Impossible de joindre le serveur. Vérifie ta connexion et réessaie.';

/**
 * Phrase à montrer pour un échec : la page fournit ses formulations par
 * statut (un 401 ne dit pas la même chose selon le lien), le reste est
 * commun : réseau coupé, trop de tentatives, panne du serveur.
 */
export function publicFailureMessage(
  cause: unknown,
  byStatus: Readonly<Partial<Record<number, string>>>,
): string {
  if (!(cause instanceof ApiError)) {
    return NETWORK_FAILURE_MESSAGE;
  }
  const specific = byStatus[cause.status];
  if (specific !== undefined) {
    return specific;
  }
  if (cause.status === 429) {
    return 'Trop de tentatives. Attends une minute, puis réessaie.';
  }
  return 'Le serveur a répondu une erreur. Réessaie dans un instant.';
}

export { isNetworkFailure };

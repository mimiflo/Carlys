import { ApiError, isNetworkFailure } from './api-transport';

/**
 * La phrase d'un chargement raté, décidée par sa CAUSE et non par la page.
 *
 * Chaque page écrivait la sienne, et chacune se trompait à sa façon : le
 * journal et la bibliothèque disaient « la permission … est requise » pour
 * TOUTE erreur, panne réseau comprise ; les autres pages conseillaient de se
 * reconnecter, y compris quand le serveur répondait 502. La personne en face
 * recevait donc un diagnostic faux, et le geste qui allait avec.
 *
 * `subject` porte l'accord (« Journal indisponible », « Catégories
 * indisponibles ») ; `permission` est celle que la route exige.
 */
export function unavailableMessage(error: unknown, subject: string, permission: string): string {
  if (error instanceof ApiError && error.status === 403) {
    return `${subject} : la permission ${permission} est requise.`;
  }
  if (error instanceof ApiError && error.status === 401) {
    // Le client a déjà oublié le jeton et la coquille renvoie vers la
    // connexion : la phrase ne se voit que le temps de la redirection.
    return `${subject} : ta session a expiré, reconnecte-toi.`;
  }
  if (isNetworkFailure(error)) {
    return `${subject} : le serveur ne répond pas. Réessaie dans un instant.`;
  }
  return `${subject} pour le moment. Réessaie dans un instant.`;
}

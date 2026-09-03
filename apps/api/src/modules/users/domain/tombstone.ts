/**
 * Valeurs tombales d'un compte supprimé.
 *
 * La ligne User reste (l'identifiant est cité par l'audit et l'historique
 * agrégé), mais l'identité est LIBÉRÉE : l'adresse d'origine redevient
 * disponible pour une nouvelle inscription, et le code ami ne résout plus
 * rien. Les deux colonnes sont uniques et non nulles : la valeur tombale est
 * dérivée de l'identifiant, donc unique par construction.
 */

/** Domaine réservé (RFC 2606) : jamais routable, jamais un vrai destinataire. */
const TOMBSTONE_EMAIL_DOMAIN = 'carlys.invalid';

export function tombstoneEmail(userId: string): string {
  return `supprime+${userId}@${TOMBSTONE_EMAIL_DOMAIN}`;
}

/**
 * Hors de l'alphabet et de la longueur des codes amis (`friend-code.ts`) :
 * ni scannable, ni dictable, ni acceptable par `normalizeFriendCode`.
 */
export function tombstoneFriendCode(userId: string): string {
  return `supprime:${userId}`;
}

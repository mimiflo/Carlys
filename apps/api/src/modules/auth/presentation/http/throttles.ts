/**
 * Limites de débit des routes d'authentification, par adresse IP, en plus
 * de la limite globale (`RATE_LIMIT_MAX_REQUESTS`).
 *
 * Elles ne remplacent pas les plafonds PAR COMPTE (verrouillage de la
 * connexion et des re-authentifications, cadence des e-mails de
 * vérification) : une limite par IP se contourne en changeant d'adresse, un
 * plafond par compte non.
 */

/** Routes sensibles à l'abus : connexion, inscription, mot de passe, suppression. */
export const STRICT_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

/**
 * Renvoi de l'e-mail de vérification : chaque appel envoie un vrai courrier,
 * à une adresse que l'appelant a pu choisir (celle d'une victime). Trois par
 * dix minutes suffisent à qui attend un lien qui tarde.
 */
export const RESEND_VERIFICATION_THROTTLE = { default: { limit: 3, ttl: 600_000 } };

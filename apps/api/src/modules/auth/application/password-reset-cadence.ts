import { type LinkCadence } from '../infrastructure/verification.repository';

/**
 * Cadence des liens de RÉINITIALISATION, par compte : un par minute au
 * plus, cinq par fenêtre, et la fenêtre dure exactement la validité d'un
 * lien (`PASSWORD_RESET_TTL_MINUTES`, une heure par défaut).
 *
 * POURQUOI. `forgot-password` n'avait que sa limite par IP : en multipliant
 * les adresses, n'importe qui envoyait un vrai courrier Carlys à n'importe
 * quelle adresse inscrite à chaque appel (mesuré : 30 appels depuis 3 IP,
 * 30 courriers en moins d'une minute). La victime était inondée, et la
 * réputation d'envoi du domaine, dont dépend la réinitialisation de tout le
 * monde, avec elle.
 *
 * POURQUOI PAS LA CADENCE DE LA VÉRIFICATION (cinq par 24 h). Cette
 * demande-ci est ANONYME : un plafond journalier laisserait quiconque connaît
 * une adresse priver son titulaire de réinitialisation 23 heures sur 24,
 * pour cinq requêtes par jour. Avec une fenêtre égale à la validité d'un
 * lien, et des liens qui ne s'invalident pas entre eux
 * ([VerificationRepository.issuePasswordReset]), une demande refusée n'est
 * jamais une impasse : si rien ne part, un lien encore valable est arrivé
 * dans la même boîte depuis moins d'une fenêtre. Le prix : au plus cinq
 * courriers par heure vers une adresse, au lieu d'un nombre illimité.
 */
export function passwordResetCadence(ttlMinutes: number): LinkCadence {
  return { cooldownMs: 60_000, maxPerWindow: 5, windowMs: ttlMinutes * 60_000 };
}

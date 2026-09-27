import { createHmac } from 'node:crypto';

/**
 * Empreinte courte et stable d'une donnée personnelle, pour les JOURNAUX et
 * l'audit.
 *
 * Les journaux sont conservés et exportés (agrégateur, Sentry) : y écrire
 * une adresse e-mail en clair en faisait un annuaire des comptes — et des
 * comptes visés par une attaque, puisque le verrouillage journalisait son
 * identifiant. L'empreinte suffit à corréler deux lignes (« le même
 * destinataire échoue en boucle ») sans dire qui c'est.
 *
 * À CLÉ, et c'est ce qui la rend sûre. Un SHA-256 nu, même tronqué à 48
 * bits, se renverse par dictionnaire : deux millions d'adresses candidates
 * (une fuite publique, un fichier clients) s'indexent en quatre secondes,
 * sans une collision, et quiconque lit l'audit retrouvait alors toutes les
 * tentatives de connexion d'une personne — y compris après l'effacement de
 * son compte. Un HMAC sous une clé que seul le serveur tient
 * (`AppConfigService.logFingerprintKey`) garde la corrélation et ôte le
 * renversement : sans la clé, une candidate ne se vérifie plus.
 */
export function logFingerprint(value: string, key: Buffer): string {
  return createHmac('sha256', key).update(value).digest('hex').slice(0, 12);
}

const EMAIL_PATTERN = /[^\s<>"'@,;:()[\]]+@[^\s<>"'@,;:()[\]]+/g;

/**
 * Retire les adresses e-mail d'un texte destiné au journal : un refus SMTP
 * cite souvent le destinataire (« 550 <nom@exemple.fr>: Recipient address
 * rejected »).
 */
export function withoutEmails(text: string): string {
  return text.replace(EMAIL_PATTERN, '<adresse>');
}

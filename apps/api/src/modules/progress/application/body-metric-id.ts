import { createHash } from 'node:crypto';

/**
 * L'identifiant SOUS LEQUEL une mesure est rangée.
 *
 * Une saisie à la main arrive sous un UUID v4 tiré au hasard : il est gardé
 * tel quel. Une pesée importée d'une balance (Health Connect, Apple Santé)
 * arrive sous un UUID v5 DÉRIVÉ de la pesée — compte, type, heure —, donc
 * recalculable par n'importe qui. Gardé tel quel, il permettait à un compte
 * de réserver la pesée d'un autre (déposée avant lui, la vraie était refusée
 * en silence) et de sonder ses heures de pesée (un 409 disait « elle existe »).
 *
 * Il est donc rangé dans l'ESPACE DU COMPTE : `uuidv5(userId, id)`. Deux
 * comptes qui envoient le même identifiant obtiennent deux lignes ; le rejeu
 * d'un même compte retombe sur la sienne (idempotence intacte) ; et le
 * résultat reste un v5, ce que l'application lit comme « importée ».
 */
export function storedBodyMetricId(userId: string, clientId: string): string {
  return uuidVersion(clientId) === 5 ? uuidv5(userId, clientId) : clientId;
}

function uuidVersion(id: string): number {
  return Number.parseInt(id.charAt(14), 16);
}

/** UUID v5 (RFC 9562, § 5.5) : SHA-1 de l'espace de noms puis du nom. */
export function uuidv5(namespace: string, name: string): string {
  const bytes = createHash('sha1')
    .update(Buffer.from(namespace.replace(/-/g, ''), 'hex'))
    .update(name, 'utf8')
    .digest()
    .subarray(0, 16);
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x50;
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

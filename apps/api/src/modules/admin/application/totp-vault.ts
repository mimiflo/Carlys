import { createCipheriv, createDecipheriv, hkdfSync, randomBytes } from 'node:crypto';

/**
 * Le secret TOTP d'un administrateur, CHIFFRÉ en base (AES-256-GCM) : une
 * copie de la base, une sauvegarde volée, ne suffit pas à fabriquer ses codes.
 * L'identifiant du compte entre comme donnée authentifiée : un secret recopié
 * sur la ligne d'un autre compte ne s'ouvre pas.
 *
 * La clé dérive du secret JWT (HKDF, contexte propre) : aucune variable de
 * plus à poser sur le serveur. Corollaire : changer JWT_ACCESS_SECRET rend
 * les secrets illisibles, et chaque administrateur se réenrôle
 * (`admin-bootstrap <email> --reset-2fa`).
 */
const VERSION = 'v1';
const TAG_BYTES = 16;

export function totpVaultKey(jwtSecret: string): Buffer {
  return Buffer.from(hkdfSync('sha256', jwtSecret, '', 'carlys/totp-admin', 32));
}

export function sealTotpSecret(secret: Buffer, key: Buffer, adminUserId: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv, { authTagLength: TAG_BYTES });
  cipher.setAAD(Buffer.from(adminUserId));
  const sealed = Buffer.concat([cipher.update(secret), cipher.final()]);
  return [VERSION, iv, cipher.getAuthTag(), sealed]
    .map((part) => (typeof part === 'string' ? part : part.toString('base64url')))
    .join('.');
}

/** `null` si la valeur a été altérée, chiffrée sous une autre clé ou pour un autre compte. */
export function openTotpSecret(stored: string, key: Buffer, adminUserId: string): Buffer | null {
  const [version, iv, tag, sealed] = stored.split('.');
  if (version !== VERSION || iv === undefined || tag === undefined || sealed === undefined) {
    return null;
  }
  try {
    const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'base64url'), {
      authTagLength: TAG_BYTES,
    });
    decipher.setAAD(Buffer.from(adminUserId));
    decipher.setAuthTag(Buffer.from(tag, 'base64url'));
    return Buffer.concat([decipher.update(Buffer.from(sealed, 'base64url')), decipher.final()]);
  } catch {
    // Étiquette d'authentification refusée : valeur altérée ou autre clé.
    return null;
  }
}

import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Mots de passe à usage unique fondés sur le temps (RFC 6238), tels que les
 * rendent Google Authenticator, Microsoft Authenticator, 1Password… : HMAC-SHA1,
 * pas de 30 s, 6 chiffres. La bibliothèque standard suffit ; aucune dépendance.
 */
const STEP_SECONDS = 30;
const DIGITS = 6;
/** Un pas de tolérance de chaque côté : l'horloge du téléphone dérive. */
const WINDOW = 1;
const BASE32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** 160 bits, la taille que recommande la RFC 4226 pour HMAC-SHA1. */
export function newTotpSecret(): Buffer {
  return randomBytes(20);
}

export function totpCode(secret: Buffer, unixSeconds: number): string {
  return hotp(secret, Math.floor(unixSeconds / STEP_SECONDS));
}

/**
 * Le pas accepté, ou `null`. Un pas inférieur ou égal à [lastStep] est refusé :
 * un code vu passer (épaule, capture) ne rouvre pas une seconde session.
 */
export function verifyTotp(
  secret: Buffer,
  code: string,
  unixSeconds: number,
  lastStep: number | null = null,
): number | null {
  if (!/^\d{6}$/.test(code)) return null;
  const current = Math.floor(unixSeconds / STEP_SECONDS);
  for (let step = current - WINDOW; step <= current + WINDOW; step += 1) {
    if (lastStep !== null && step <= lastStep) continue;
    if (timingSafeEqual(Buffer.from(hotp(secret, step)), Buffer.from(code))) return step;
  }
  return null;
}

/** L'adresse que l'appli d'authentification lit dans le QR code. */
export function otpauthUri(secret: Buffer, account: string, issuer: string): string {
  const label = encodeURIComponent(`${issuer}:${account}`);
  const query = new URLSearchParams({ secret: base32Encode(secret), issuer, digits: '6' });
  return `otpauth://totp/${label}?${query.toString()}`;
}

function hotp(secret: Buffer, counter: number): string {
  const message = Buffer.alloc(8);
  message.writeBigUInt64BE(BigInt(counter));
  const hmac = createHmac('sha1', secret).update(message).digest();
  const offset = (hmac[hmac.length - 1] ?? 0) & 0x0f;
  const binary = hmac.readUInt32BE(offset) & 0x7fffffff;
  return String(binary % 10 ** DIGITS).padStart(DIGITS, '0');
}

export function base32Encode(bytes: Buffer): string {
  let bits = 0;
  let value = 0;
  let output = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += BASE32[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += BASE32[(value << (5 - bits)) & 31];
  return output;
}

export function base32Decode(text: string): Buffer {
  const clean = text.toUpperCase().replace(/[\s=]/g, '');
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const char of clean) {
    const index = BASE32.indexOf(char);
    if (index < 0) throw new Error('Clé base32 invalide.');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

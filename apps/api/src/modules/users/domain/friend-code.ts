import { randomInt } from 'node:crypto';

/**
 * Code ami : l'identité PARTAGEABLE d'un compte, à la Snapchat — on la
 * donne de vive voix, on la tape, on la porte en QR sur son profil.
 *
 * Huit caractères d'un alphabet sans ambiguïté visuelle : ni 0/O, ni 1/I/L,
 * ni B/8, G/6, S/5, Z/2, Q/O. Un code se dicte au téléphone sans épeler.
 * 26⁸ ≈ 2×10¹¹ combinaisons : introuvable par essais successifs (le
 * throttler global fait le reste), mais assez court pour tenir sur une
 * carte de profil.
 */
export const FRIEND_CODE_ALPHABET = '23456789ACDEFHJKMNPRTUVWXY';

export const FRIEND_CODE_LENGTH = 8;

/** Forme canonique stockée : 8 caractères de l'alphabet, sans séparateur. */
const CANONICAL = new RegExp(`^[${FRIEND_CODE_ALPHABET}]{${FRIEND_CODE_LENGTH}}$`);

/** Tirage cryptographique — `randomInt` est uniforme, pas de biais modulo. */
export function generateFriendCode(): string {
  let code = '';
  for (let i = 0; i < FRIEND_CODE_LENGTH; i += 1) {
    code += FRIEND_CODE_ALPHABET[randomInt(FRIEND_CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * Ramène une saisie humaine à la forme canonique, ou `null` si ce n'en est
 * pas une. Tolère la casse, les espaces et les tirets (la forme affichée
 * `XXXX-XXXX` doit se recoller telle quelle), et le préfixe des QR.
 */
export function normalizeFriendCode(raw: string): string | null {
  const stripped = raw.replace(FRIEND_CODE_QR_PREFIX, '').replace(/[\s-]/g, '').toUpperCase();
  return CANONICAL.test(stripped) ? stripped : null;
}

/** Forme affichée : `XXXX-XXXX`, plus lisible et plus facile à dicter. */
export function formatFriendCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/**
 * Charge utile des QR de profil. Le préfixe distingue un QR Carlys de
 * n'importe quel autre code scanné par erreur — le scanner mobile refuse
 * tout ce qui ne le porte pas.
 */
export const FRIEND_CODE_QR_PREFIX = 'carlys:friend:';

export function friendCodeQrPayload(code: string): string {
  return `${FRIEND_CODE_QR_PREFIX}${code}`;
}

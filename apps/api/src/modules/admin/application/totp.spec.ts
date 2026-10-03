import { base32Decode, base32Encode, newTotpSecret, totpCode, verifyTotp } from './totp';

/** Secret de la RFC 6238 (annexe B), « 12345678901234567890 » en ASCII. */
const RFC_SECRET = Buffer.from('12345678901234567890');

describe('TOTP (RFC 6238, SHA-1, 30 s)', () => {
  it('rend les codes des vecteurs de la RFC, tronqués à 6 chiffres', () => {
    // Annexe B : 94287082, 07081804, 14050471, 89005924 (8 chiffres).
    expect(totpCode(RFC_SECRET, 59)).toBe('287082');
    expect(totpCode(RFC_SECRET, 1111111109)).toBe('081804');
    expect(totpCode(RFC_SECRET, 1111111111)).toBe('050471');
    expect(totpCode(RFC_SECRET, 1234567890)).toBe('005924');
  });

  it('accepte le pas courant et ses voisins immédiats, rend le pas utilisé', () => {
    const now = 1_234_567_890;
    const step = Math.floor(now / 30);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now), now)).toBe(step);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now - 30), now)).toBe(step - 1);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now + 30), now)).toBe(step + 1);
  });

  it('refuse un code trop ancien, faux ou mal formé', () => {
    const now = 1_234_567_890;
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, now - 90), now)).toBeNull();
    expect(verifyTotp(RFC_SECRET, '000000', now)).toBeNull();
    expect(verifyTotp(RFC_SECRET, '12345', now)).toBeNull();
    expect(verifyTotp(RFC_SECRET, 'abcdef', now)).toBeNull();
  });

  it('un code déjà utilisé (pas ≤ dernier pas accepté) est refusé : pas de rejeu', () => {
    const now = 1_234_567_890;
    const code = totpCode(RFC_SECRET, now);
    const step = verifyTotp(RFC_SECRET, code, now);
    expect(step).not.toBeNull();
    expect(verifyTotp(RFC_SECRET, code, now, step)).toBeNull();
  });

  it('base32 : aller-retour exact, et les espaces ou minuscules saisis passent', () => {
    const secret = newTotpSecret();
    expect(secret).toHaveLength(20);
    const encoded = base32Encode(secret);
    expect(encoded).toMatch(/^[A-Z2-7]{32}$/);
    expect(base32Decode(encoded)).toEqual(secret);
    expect(base32Decode(encoded.toLowerCase().replace(/(.{4})/g, '$1 '))).toEqual(secret);
  });
});

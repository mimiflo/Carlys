import { newTotpSecret } from './totp';
import { openTotpSecret, sealTotpSecret, totpVaultKey } from './totp-vault';

describe('coffre des secrets TOTP', () => {
  const key = totpVaultKey('secret-jwt-de-test-32-caracteres-minimum');
  const ADMIN = '6f1c0b52-2d1e-4d55-9a57-3f3a1d1e0a01';

  it('chiffre puis rend le secret ; jamais en clair dans la valeur stockée', () => {
    const secret = newTotpSecret();
    const stored = sealTotpSecret(secret, key, ADMIN);
    expect(stored).not.toContain(secret.toString('base64url'));
    expect(openTotpSecret(stored, key, ADMIN)).toEqual(secret);
  });

  it('valeur altérée ou autre clé : null, jamais un secret faux', () => {
    const stored = sealTotpSecret(newTotpSecret(), key, ADMIN);
    expect(
      openTotpSecret(stored, totpVaultKey('un-autre-secret-jwt-32-caracteres-xx'), ADMIN),
    ).toBeNull();
    const [v, iv, tag] = stored.split('.');
    expect(openTotpSecret([v, iv, tag, 'AAAA'].join('.'), key, ADMIN)).toBeNull();
    expect(openTotpSecret('n-importe-quoi', key, ADMIN)).toBeNull();
  });

  it('recopié sur la ligne d’un autre compte : illisible', () => {
    const stored = sealTotpSecret(newTotpSecret(), key, ADMIN);
    expect(openTotpSecret(stored, key, '0b9d7a3e-8f6a-4f3b-9d0e-2c4b6a8e1f02')).toBeNull();
  });
});

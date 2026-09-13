import { UnauthorizedException } from '@nestjs/common';
import { createLocalJWKSet, exportJWK, generateKeyPair, type JWK, SignJWT } from 'jose';
import { type SocialKeyStore, SocialTokenVerifier } from './social-token-verifier';

/**
 * CE QUI EST VRAIMENT VÉRIFIÉ ICI : la vérification cryptographique, pas une
 * simulation. Les jetons sont SIGNÉS pour de bon (jose, RS256) avec une paire
 * de clés engendrée dans le test ; seule la PROVENANCE des clés change — un
 * trousseau local au lieu du trousseau distant du fournisseur.
 *
 * Un jeton forgé avec une autre clé, un émetteur inattendu, une audience
 * étrangère ou une date dépassée doit être refusé. C'est tout l'intérêt du
 * fichier : sans ces quatre refus, « vérifier le jeton » ne veut rien dire, et
 * n'importe qui pourrait se connecter au compte de n'importe qui.
 */
describe('SocialTokenVerifier', () => {
  const GOOGLE_AUDIENCE = '1234.apps.googleusercontent.com';
  const APPLE_AUDIENCE = 'com.carlys.app';

  let signer: CryptoKey;
  let etrangere: CryptoKey;
  let jwks: { keys: JWK[] };
  let verifier: SocialTokenVerifier;

  beforeAll(async () => {
    const paire = await generateKeyPair('RS256', { extractable: true });
    const autre = await generateKeyPair('RS256', { extractable: true });
    signer = paire.privateKey;
    etrangere = autre.privateKey;
    jwks = { keys: [{ ...(await exportJWK(paire.publicKey)), alg: 'RS256', kid: 'carlys-test' }] };

    const keyStore: Pick<SocialKeyStore, 'keyFor'> = {
      keyFor: () => createLocalJWKSet(jwks),
    };
    verifier = new SocialTokenVerifier(keyStore as SocialKeyStore);
  });

  /** Un jeton d'identité réaliste, signé par la clé du trousseau. */
  async function jeton(
    claims: Record<string, unknown>,
    options: { issuer?: string; audience?: string; expiration?: string; cle?: CryptoKey } = {},
  ): Promise<string> {
    return new SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256', kid: 'carlys-test' })
      .setIssuer(options.issuer ?? 'https://accounts.google.com')
      .setAudience(options.audience ?? GOOGLE_AUDIENCE)
      .setIssuedAt()
      .setExpirationTime(options.expiration ?? '10m')
      .sign(options.cle ?? signer);
  }

  it('lit le sujet, l’adresse et le nom d’un jeton Google valide', async () => {
    const claims = await verifier.verify(
      'google',
      await jeton({
        sub: 'google-sub-1',
        email: 'camille@example.com',
        email_verified: true,
        name: 'Camille',
      }),
      [GOOGLE_AUDIENCE],
    );

    expect(claims).toEqual({
      subject: 'google-sub-1',
      email: 'camille@example.com',
      emailVerified: true,
      displayName: 'Camille',
    });
  });

  it('accepte la forme Apple : émetteur propre, email_verified en CHAÎNE', async () => {
    // Apple sérialise le booléen en texte. Le lire comme un booléen JS
    // strict ferait passer toutes ses adresses pour non vérifiées, et donc
    // refuserait toute création de compte par Apple.
    const claims = await verifier.verify(
      'apple',
      await jeton(
        { sub: 'apple-sub-1', email: 'camille@privaterelay.appleid.com', email_verified: 'true' },
        { issuer: 'https://appleid.apple.com', audience: APPLE_AUDIENCE },
      ),
      [APPLE_AUDIENCE],
    );

    expect(claims.subject).toBe('apple-sub-1');
    expect(claims.emailVerified).toBe(true);
    // Apple ne met JAMAIS le nom dans le jeton : le client doit le faire suivre.
    expect(claims.displayName).toBeNull();
  });

  it('refuse un jeton signé par une AUTRE clé', async () => {
    await expect(
      verifier.verify('google', await jeton({ sub: 'x' }, { cle: etrangere }), [GOOGLE_AUDIENCE]),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refuse un émetteur inattendu', async () => {
    await expect(
      verifier.verify('google', await jeton({ sub: 'x' }, { issuer: 'https://evil.example' }), [
        GOOGLE_AUDIENCE,
      ]),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refuse une audience qui n’est pas la nôtre', async () => {
    // Le cas dangereux : un jeton Google parfaitement valide, mais émis pour
    // l'application de quelqu'un d'autre. L'accepter laisserait n'importe
    // quel développeur tiers ouvrir une session sur n'importe quel compte.
    await expect(
      verifier.verify('google', await jeton({ sub: 'x' }, { audience: 'autre-app' }), [
        GOOGLE_AUDIENCE,
      ]),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refuse un jeton expiré', async () => {
    await expect(
      verifier.verify('google', await jeton({ sub: 'x' }, { expiration: '-1m' }), [
        GOOGLE_AUDIENCE,
      ]),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refuse un jeton sans sujet : il n’identifie personne', async () => {
    await expect(
      verifier.verify('google', await jeton({ email: 'a@b.test' }), [GOOGLE_AUDIENCE]),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('accepte l’une QUELCONQUE des audiences configurées', async () => {
    // Trois plateformes, trois client IDs : Android, iOS et le « Web » que
    // Google impose comme audience serveur.
    const claims = await verifier.verify('google', await jeton({ sub: 'multi' }), [
      'android.apps.googleusercontent.com',
      GOOGLE_AUDIENCE,
      'ios.apps.googleusercontent.com',
    ]);

    expect(claims.subject).toBe('multi');
  });

  it('une adresse non vérifiée reste non vérifiée', async () => {
    const claims = await verifier.verify(
      'google',
      await jeton({ sub: 's', email: 'a@b.test', email_verified: false }),
      [GOOGLE_AUDIENCE],
    );

    expect(claims.emailVerified).toBe(false);
  });
});

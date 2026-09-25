import { UnauthorizedException } from '@nestjs/common';
import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  type JWK,
  type KeyLike,
  SignJWT,
} from 'jose';
import { type PinoLogger } from 'nestjs-pino';
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

  let signer: KeyLike;
  let etrangere: KeyLike;
  let jwks: { keys: JWK[] };
  let verifier: SocialTokenVerifier;

  /**
   * Le refus reste nu côté client ; côté serveur il doit être MOTIVÉ. Ce
   * double est là pour que les tests puissent l'exiger, pas pour décorer.
   */
  const warn = jest.fn();
  const logger = { warn } as unknown as PinoLogger;

  beforeAll(async () => {
    const paire = await generateKeyPair('RS256', { extractable: true });
    const autre = await generateKeyPair('RS256', { extractable: true });
    signer = paire.privateKey;
    etrangere = autre.privateKey;
    jwks = { keys: [{ ...(await exportJWK(paire.publicKey)), alg: 'RS256', kid: 'carlys-test' }] };

    const keyStore: Pick<SocialKeyStore, 'keyFor'> = {
      keyFor: () => createLocalJWKSet(jwks),
    };
    verifier = new SocialTokenVerifier(keyStore as SocialKeyStore, logger);
  });

  beforeEach(() => jest.clearAllMocks());

  /** Un jeton d'identité réaliste, signé par la clé du trousseau. */
  async function jeton(
    claims: Record<string, unknown>,
    options: {
      issuer?: string;
      audience?: string;
      expiration?: string;
      cle?: KeyLike;
      /** Recule (valeur positive) ou avance (négative) `iat`, en secondes. */
      emisIlYaSecondes?: number;
    } = {},
  ): Promise<string> {
    const emission = Math.floor(Date.now() / 1000) - (options.emisIlYaSecondes ?? 0);
    return new SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256', kid: 'carlys-test' })
      .setIssuer(options.issuer ?? 'https://accounts.google.com')
      .setAudience(options.audience ?? GOOGLE_AUDIENCE)
      .setIssuedAt(emission)
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

  /**
   * LA FENÊTRE D'ÂGE, éprouvée des deux côtés.
   *
   * Elle n'était couverte par aucun test : n'importe quelle valeur de
   * `MAX_TOKEN_AGE` — dix minutes, une seconde, un an — gardait la suite
   * verte. Or elle est mécaniquement liée au mobile : Android ne sait PAS
   * régénérer un jeton d'identité (google_sign_in 6.3.0 réutilise celui de
   * la première connexion), donc la passerelle Dart oublie le compte avant
   * chaque demande pour en obtenir un frais. Ces deux tests tiennent les
   * deux bords de cet accord : trop vieux se refuse, dans la fenêtre
   * s'accepte.
   */
  it('refuse un jeton d’identité plus vieux que la fenêtre, même non expiré', async () => {
    // DOUZE minutes, pas onze : le plafond réel est
    // `MAX_TOKEN_AGE + CLOCK_TOLERANCE`, jose ADDITIONNE la tolérance à
    // l'âge maximal au lieu de la retrancher. Un test posé à onze minutes
    // pile tombait sur la borne, passait, et laissait croire que la garde
    // ne mordait pas du tout.
    const vieux = await jeton({ sub: 'vieux' }, { emisIlYaSecondes: 12 * 60 });

    await expect(verifier.verify('google', vieux, [GOOGLE_AUDIENCE])).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('accepte un jeton encore dans la fenêtre', async () => {
    const frais = await jeton({ sub: 'frais' }, { emisIlYaSecondes: 9 * 60 });

    await expect(verifier.verify('google', frais, [GOOGLE_AUDIENCE])).resolves.toMatchObject({
      subject: 'frais',
    });
  });

  it('tolère une horloge de fournisseur en avance sur la nôtre', async () => {
    // `iat` est daté par Google, jamais par le téléphone. Trente secondes
    // d'avance chez eux faisaient échouer « iat claim timestamp check » sur
    // un jeton parfaitement légitime, en rendant ce refus indiscernable
    // d'un vrai. Sans `clockTolerance`, ce test échoue.
    const enAvance = await jeton({ sub: 'avance' }, { emisIlYaSecondes: -30 });

    await expect(verifier.verify('google', enAvance, [GOOGLE_AUDIENCE])).resolves.toMatchObject({
      subject: 'avance',
    });
  });

  it('écrit le motif du refus dans les journaux, sans le dire au client', async () => {
    // Cinq causes très différentes rendent le même 401 : audience mal
    // configurée, trousseau injoignable, horloge qui dérive, jeton périmé,
    // signature fausse. Les taire AUSSI côté serveur rendait le diagnostic
    // impossible. La réponse, elle, ne dit toujours rien.
    await expect(
      verifier.verify('google', await jeton({ sub: 'x' }, { cle: etrangere }), [GOOGLE_AUDIENCE]),
    ).rejects.toThrow('Google n’a pas pu confirmer ton identité.');

    expect(warn).toHaveBeenCalledTimes(1);
    const [details] = warn.mock.calls[0] as [Record<string, unknown>];
    expect(details.provider).toBe('google');
    expect(details.raison).toEqual(expect.any(String));
    expect(details.raison).not.toBe('');
  });
});

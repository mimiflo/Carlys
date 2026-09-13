import { type SocialProvider } from '@carlys/api-contracts';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';

/** Ce que le jeton d'identité prouve, une fois vérifié. */
export interface SocialIdentityClaims {
  /** Identifiant STABLE du compte chez le fournisseur (claim `sub`). */
  subject: string;
  email: string | null;
  /** Le fournisseur a-t-il lui-même vérifié cette adresse ? */
  emailVerified: boolean;
  /** Nom transmis par Google (`name`) — Apple ne le met jamais dans le jeton. */
  displayName: string | null;
}

/**
 * Émetteurs et trousseaux OFFICIELS. Google signe historiquement avec les
 * deux formes d'émetteur ; Apple avec une seule.
 */
const ISSUERS: Record<SocialProvider, string[]> = {
  google: ['https://accounts.google.com', 'accounts.google.com'],
  apple: ['https://appleid.apple.com'],
};

/**
 * Âge maximal d'un jeton d'identité accepté. Il sert à ouvrir une session
 * dans la seconde qui suit son obtention ; dix minutes laissent de la marge
 * à une horloge d'appareil approximative sans rendre un jeton intercepté
 * utile bien longtemps.
 */
const MAX_TOKEN_AGE = '10 minutes';

/**
 * Tolérance d'horloge entre NOTRE serveur et celui du fournisseur.
 *
 * `iat` est daté par Google ou Apple, jamais par le téléphone. Sans cette
 * marge, une seconde d'avance chez eux — ou de retard chez nous — suffit à
 * faire échouer « iat claim timestamp check » sur un jeton parfaitement
 * légitime, en rendant un 401 indiscernable d'un vrai refus. Soixante
 * secondes couvrent la dérive d'un serveur synchronisé sans ouvrir de
 * fenêtre utile à un rejeu.
 */
const CLOCK_TOLERANCE = '60 seconds';

const JWKS_URLS: Record<SocialProvider, string> = {
  google: 'https://www.googleapis.com/oauth2/v3/certs',
  apple: 'https://appleid.apple.com/auth/keys',
};

/**
 * Trousseau de clés publiques par fournisseur — la SEULE pièce qui touche le
 * réseau. `createRemoteJWKSet` met les clés en cache et les rafraîchit tout
 * seul quand un `kid` inconnu se présente (rotation côté fournisseur).
 *
 * Isolé dans sa propre classe pour être SUBSTITUABLE : les tests injectent un
 * trousseau local (`createLocalJWKSet`) et signent leurs propres jetons —
 * aucune vérification n'est simulée, seule la provenance des clés change.
 */
@Injectable()
export class SocialKeyStore {
  private readonly cache = new Map<SocialProvider, JWTVerifyGetKey>();

  keyFor(provider: SocialProvider): JWTVerifyGetKey {
    let keys = this.cache.get(provider);
    if (keys === undefined) {
      keys = createRemoteJWKSet(new URL(JWKS_URLS[provider]));
      this.cache.set(provider, keys);
    }
    return keys;
  }
}

/**
 * Vérification d'un jeton d'identité Apple ou Google : signature contre le
 * trousseau du fournisseur, émetteur attendu, audience dans la liste
 * configurée, expiration. Tout échec est un 401 — le détail exact reste dans
 * les logs du fournisseur, pas dans la réponse.
 */
@Injectable()
export class SocialTokenVerifier {
  constructor(
    private readonly keys: SocialKeyStore,
    @InjectPinoLogger(SocialTokenVerifier.name)
    private readonly logger: PinoLogger,
  ) {}

  async verify(
    provider: SocialProvider,
    idToken: string,
    audiences: string[],
  ): Promise<SocialIdentityClaims> {
    try {
      const { payload } = await jwtVerify(idToken, this.keys.keyFor(provider), {
        issuer: ISSUERS[provider],
        audience: audiences,
        // jose n'exige aucun claim par défaut : un jeton sans `exp`, bien
        // signé et bien adressé, serait éternel. Apple et Google en mettent
        // toujours un — raison de plus pour que son absence soit un refus.
        requiredClaims: ['sub', 'iat', 'exp'],
        maxTokenAge: MAX_TOKEN_AGE,
        clockTolerance: CLOCK_TOLERANCE,
      });
      if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
        throw new Error('sub absent');
      }
      return {
        subject: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : null,
        // Google émet un booléen ; Apple, la chaîne 'true'/'false'.
        emailVerified: payload.email_verified === true || payload.email_verified === 'true',
        displayName:
          typeof payload.name === 'string' && payload.name.trim().length > 0
            ? payload.name.trim()
            : null,
      };
    } catch (error) {
      // Le refus reste un 401 NU côté client — on ne dit jamais à un
      // appelant anonyme POURQUOI son jeton est refusé, ce serait lui
      // apprendre à en fabriquer un meilleur. Mais le taire AUSSI dans nos
      // journaux rendait indiscernables cinq causes très différentes :
      // audience mal configurée, trousseau JWKS injoignable, horloge qui
      // dérive, jeton périmé, signature fausse. Ici, corrélé au requestId,
      // le motif est écrit une fois, côté serveur seulement.
      this.logger.warn(
        {
          provider,
          // jose nomme ses refus (`ERR_JWT_EXPIRED`,
          // `ERR_JWT_CLAIM_VALIDATION_FAILED`…) : c'est ce code qui dit
          // laquelle des cinq causes a joué.
          raison: error instanceof Error ? error.message : 'inconnue',
          code:
            error !== null && typeof error === 'object' && 'code' in error
              ? String(error.code)
              : undefined,
          audiencesConfigurees: audiences.length,
        },
        'Jeton social refusé',
      );
      throw new UnauthorizedException(
        provider === 'apple' ? 'Jeton Apple invalide.' : 'Jeton Google invalide.',
      );
    }
  }
}

import { type SocialProvider } from '@carlys/api-contracts';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';

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
  constructor(private readonly keys: SocialKeyStore) {}

  async verify(
    provider: SocialProvider,
    idToken: string,
    audiences: string[],
  ): Promise<SocialIdentityClaims> {
    try {
      const { payload } = await jwtVerify(idToken, this.keys.keyFor(provider), {
        issuer: ISSUERS[provider],
        audience: audiences,
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
    } catch {
      throw new UnauthorizedException(
        provider === 'apple' ? 'Jeton Apple invalide.' : 'Jeton Google invalide.',
      );
    }
  }
}

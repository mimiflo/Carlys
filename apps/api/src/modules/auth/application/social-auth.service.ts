import { type AuthResult, type SocialProvider } from '@carlys/api-contracts';
import { Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ExternalIdentityProvider, UserStatus } from '@prisma/client';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AppConfigService } from '../../../config/app-config.service';
import { AuditService } from '../../audit/audit.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { IdentitiesRepository, type IdentityOwner } from '../infrastructure/identities.repository';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { VerificationRepository } from '../infrastructure/verification.repository';
import { normalizeEmail } from './auth.service';
import { type DeviceInfo, SessionsService } from './sessions.service';
import { type SocialIdentityClaims, SocialTokenVerifier } from './social-token-verifier';
import { presentUser } from './user.presenter';

const PROVIDER_ENUM: Record<SocialProvider, ExternalIdentityProvider> = {
  apple: ExternalIdentityProvider.APPLE,
  google: ExternalIdentityProvider.GOOGLE,
};

const PROVIDER_LABEL: Record<SocialProvider, string> = {
  apple: 'Apple',
  google: 'Google',
};

export interface SocialLoginInput extends DeviceInfo {
  provider: SocialProvider;
  idToken: string;
  /** Nom transmis par le SDK à la première connexion (Apple, surtout). */
  displayName?: string;
}

/**
 * Connexion via Apple ou Google : le serveur vérifie le jeton d'IDENTITÉ
 * (signature, émetteur, audience) puis émet les MÊMES sessions que la
 * connexion par e-mail — rien ne change en aval de l'authentification.
 *
 * Trois issues, dans cet ordre :
 *  1. identité (provider, sub) connue → connexion ;
 *  2. adresse e-mail d'un compte existant, VÉRIFIÉE par le fournisseur →
 *     rattachement de l'identité à ce compte, puis connexion ;
 *  3. personne → création d'un compte SANS mot de passe (aucune ligne
 *     credential), adresse marquée vérifiée si le fournisseur la garantit.
 */
@Injectable()
export class SocialAuthService {
  constructor(
    private readonly users: UsersRepository,
    private readonly identities: IdentitiesRepository,
    private readonly sessions: SessionsRepository,
    private readonly verifications: VerificationRepository,
    private readonly sessionsService: SessionsService,
    private readonly verifier: SocialTokenVerifier,
    private readonly audit: AuditService,
    private readonly config: AppConfigService,
  ) {}

  async login(input: SocialLoginInput, client: RequestClientContext): Promise<AuthResult> {
    const { provider } = input;
    const audiences =
      provider === 'google' ? this.config.googleOauthClientIds : this.config.appleOauthAudiences;
    if (audiences.length === 0) {
      // Même politique que le coach : indisponible, pas en panne — le client
      // peut le dire honnêtement au lieu d'afficher une erreur. Ce que le
      // client LIT, c'est le code `SERVICE_UNAVAILABLE` de l'enveloppe : le
      // filtre masque le message des 5xx (aucune fuite d'interne), la phrase
      // ci-dessous ne vit donc que dans les logs et Swagger.
      throw new ServiceUnavailableException(
        `La connexion avec ${PROVIDER_LABEL[provider]} n'est pas encore activée sur ce serveur.`,
      );
    }

    const claims = await this.verifier.verify(provider, input.idToken, audiences);
    const providerEnum = PROVIDER_ENUM[provider];

    const owner = await this.identities.findOwner(providerEnum, claims.subject);
    if (owner !== null) {
      return this.open(owner, input, client, 'auth.social_login');
    }

    const linked = await this.linkOrCreate(providerEnum, claims, input, client);
    return linked;
  }

  /** Issues 2 et 3 — séparées de `login` pour rester lisibles. */
  private async linkOrCreate(
    provider: ExternalIdentityProvider,
    claims: SocialIdentityClaims,
    input: SocialLoginInput,
    client: RequestClientContext,
  ): Promise<AuthResult> {
    if (claims.email === null || !claims.emailVerified) {
      // Sans adresse garantie par le fournisseur, ni rattachement (risque de
      // capture d'un compte existant) ni création (compte sans contact sûr).
      // Le refus le plus intéressant à surveiller est aussi le seul qui ne
      // vient d'aucun compte : il se trace quand même.
      this.audit.record({
        action: 'auth.social_login_refused_unverified_email',
        ...client,
        metadata: { provider: input.provider },
      });
      throw new UnauthorizedException(
        "Le fournisseur n'a pas transmis d'adresse e-mail vérifiée. " +
          'Connecte-toi avec ton adresse e-mail.',
      );
    }
    const email = normalizeEmail(claims.email);

    const existing = await this.users.findActiveByEmail(email);
    if (existing !== null) {
      // Le compte est-il utilisable ? On refuse AVANT d'écrire quoi que ce
      // soit : rattacher une identité à un compte suspendu, ou lui marquer
      // son adresse vérifiée, serait modifier l'état d'un compte auquel on
      // vient précisément d'interdire l'accès.
      this.refuserSiInactif(existing, input, client);

      const neuf = existing.emailVerifiedAt === null;
      const attached = await this.identities.attach(existing.id, provider, claims.subject, email);
      if (!attached) {
        // Course entre deux premières connexions : l'identité vient d'être
        // rattachée par l'autre requête — on repart comme une connexion.
        const owner = await this.identities.findOwner(provider, claims.subject);
        if (owner === null) {
          throw new UnauthorizedException('Connexion impossible avec ce compte.');
        }
        return this.open(owner, input, client, 'auth.social_login');
      }

      if (neuf) {
        // LE COMPTE LOCAL N'AVAIT JAMAIS PROUVÉ CETTE ADRESSE.
        //
        // N'importe qui peut s'inscrire avec l'adresse d'un autre : le compte
        // est utilisable immédiatement, la vérification n'est qu'une
        // bannière. Quelqu'un a donc pu s'installer à l'avance sur l'adresse
        // de la personne qui arrive maintenant, mot de passe en poche et
        // session ouverte — et le rattachement lui aurait livré le compte,
        // avec ses données, pour toujours.
        //
        // Le fournisseur, lui, VIENT de prouver la propriété de l'adresse.
        // C'est donc la personne qui arrive qui est chez elle : tout ce qui
        // pouvait appartenir à quelqu'un d'autre tombe — les sessions
        // ouvertes, le mot de passe, les réinitialisations en cours. Elle
        // repart d'une porte unique, la sienne ; l'autre n'a plus rien.
        await this.reprendreLeCompte(existing.id, input, client);
        await this.users.markEmailVerified(existing.id);
        // On RELIT : présenter le compte lu avant l'écriture annoncerait une
        // adresse non vérifiée juste après l'avoir vérifiée, et le client
        // relancerait une demande de vérification sans objet.
        const rafraichi = await this.users.findActiveById(existing.id);
        return this.open(rafraichi ?? existing, input, client, 'auth.social_linked');
      }
      return this.open(existing, input, client, 'auth.social_linked');
    }

    const displayName =
      input.displayName?.trim() ?? claims.displayName ?? email.split('@')[0] ?? 'Athlète';
    const user = await this.users.create({
      email,
      displayName: displayName.length > 0 ? displayName : 'Athlète',
      emailVerifiedAt: new Date(),
    });
    const rattachee = await this.identities.attach(user.id, provider, claims.subject, email);
    if (!rattachee) {
      // Le compte vient d'être créé, mais son identité est déjà prise : une
      // requête concurrente est passée entre les deux. Ouvrir la session
      // laisserait un compte orphelin qu'aucune connexion sociale ne
      // retrouverait — on préfère refuser et laisser réessayer.
      this.audit.record({
        action: 'auth.social_attach_conflict',
        userId: user.id,
        ...client,
        metadata: { provider: input.provider },
      });
      throw new UnauthorizedException('Connexion impossible avec ce compte.');
    }
    return this.open(user, input, client, 'auth.social_registered');
  }

  /**
   * Tout ce qui, sur ce compte, a pu être posé par quelqu'un d'AUTRE avant
   * que le fournisseur ne prouve l'adresse.
   */
  private async reprendreLeCompte(
    userId: string,
    input: SocialLoginInput,
    client: RequestClientContext,
  ): Promise<void> {
    await this.sessions.revokeAllSessions(userId, 'social_link_unverified_email');
    await this.users.deleteCredential(userId);
    await this.verifications.invalidateOpenPasswordResets(userId);
    this.audit.record({
      action: 'auth.social_claimed_unverified_account',
      userId,
      ...client,
      metadata: { provider: input.provider },
    });
  }

  /** Refus AVANT toute écriture, avec sa trace. */
  private refuserSiInactif(
    user: IdentityOwner,
    input: SocialLoginInput,
    client: RequestClientContext,
  ): void {
    if (user.status === UserStatus.ACTIVE) return;
    this.audit.record({
      action: 'auth.social_login_blocked',
      userId: user.id,
      ...client,
      metadata: { provider: input.provider },
    });
    throw new UnauthorizedException('Connexion impossible avec ce compte.');
  }

  private async open(
    user: IdentityOwner,
    input: SocialLoginInput,
    client: RequestClientContext,
    action: string,
  ): Promise<AuthResult> {
    this.refuserSiInactif(user, input, client);
    this.audit.record({
      action,
      userId: user.id,
      ...client,
      metadata: { provider: input.provider },
    });
    const tokens = await this.sessionsService.open(user.id, input, client);
    return { user: presentUser(user), tokens };
  }
}

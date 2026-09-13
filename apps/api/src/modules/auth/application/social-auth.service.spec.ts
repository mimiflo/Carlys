import { ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ExternalIdentityProvider, UserStatus } from '@prisma/client';
import { type AppConfigService } from '../../../config/app-config.service';
import { type AuditService } from '../../audit/audit.service';
import { type UsersRepository } from '../../users/infrastructure/users.repository';
import {
  type IdentitiesRepository,
  type IdentityOwner,
} from '../infrastructure/identities.repository';
import { type SessionsRepository } from '../infrastructure/sessions.repository';
import { type VerificationRepository } from '../infrastructure/verification.repository';
import { type SessionsService } from './sessions.service';
import { SocialAuthService } from './social-auth.service';
import { type SocialIdentityClaims, type SocialTokenVerifier } from './social-token-verifier';

/**
 * CE QUE CE FICHIER DÉFEND : à qui la connexion sociale ouvre une session.
 *
 * La question dangereuse n'est pas « le jeton est-il valide » (c'est l'affaire
 * du vérificateur, éprouvée à côté) mais « ce jeton valide donne-t-il accès au
 * bon compte ». Trois issues sont légitimes — identité connue, adresse
 * VÉRIFIÉE d'un compte existant, création — et une quatrième serait une
 * catastrophe : rattacher une identité à un compte dont le fournisseur ne
 * garantit pas l'adresse laisserait prendre le compte de quelqu'un d'autre.
 */
describe('SocialAuthService', () => {
  const client = { ipAddress: '10.0.0.1', userAgent: 'jest', requestId: 'req-1' };
  const TOKENS = {
    accessToken: 'access',
    accessTokenExpiresIn: 900,
    refreshToken: 'refresh',
    refreshTokenExpiresAt: '2026-01-01T00:00:00.000Z',
  };

  function utilisateur(overrides: Partial<IdentityOwner> = {}): IdentityOwner {
    return {
      id: 'user-1',
      email: 'camille@example.com',
      friendCode: 'ABCD-EFGH',
      status: UserStatus.ACTIVE,
      emailVerifiedAt: new Date('2026-01-01'),
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
      deletedAt: null,
      profile: {
        userId: 'user-1',
        displayName: 'Camille',
        locale: 'fr',
        timezone: 'Europe/Paris',
        carlysProfile: null,
        createdAt: new Date('2026-01-01'),
        updatedAt: new Date('2026-01-01'),
      },
      ...overrides,
    } as IdentityOwner;
  }

  interface Stubs {
    users: jest.Mocked<
      Pick<
        UsersRepository,
        'findActiveByEmail' | 'findActiveById' | 'create' | 'markEmailVerified' | 'deleteCredential'
      >
    >;
    identities: jest.Mocked<Pick<IdentitiesRepository, 'findOwner' | 'attach'>>;
    sessions: jest.Mocked<Pick<SessionsRepository, 'revokeAllSessions'>>;
    verifications: jest.Mocked<Pick<VerificationRepository, 'invalidateOpenPasswordResets'>>;
    sessionsService: jest.Mocked<Pick<SessionsService, 'open'>>;
    verifier: jest.Mocked<Pick<SocialTokenVerifier, 'verify'>>;
    audit: jest.Mocked<Pick<AuditService, 'record'>>;
  }

  function monter(
    claims: Partial<SocialIdentityClaims> = {},
    audiences: { google?: string[]; apple?: string[] } = {},
  ): { service: SocialAuthService; stubs: Stubs } {
    const stubs: Stubs = {
      users: {
        findActiveByEmail: jest.fn().mockResolvedValue(null),
        findActiveById: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(utilisateur({ id: 'user-neuf' })),
        markEmailVerified: jest.fn().mockResolvedValue(undefined),
        deleteCredential: jest.fn().mockResolvedValue(undefined),
      },
      identities: {
        findOwner: jest.fn().mockResolvedValue(null),
        attach: jest.fn().mockResolvedValue(true),
      },
      sessions: { revokeAllSessions: jest.fn().mockResolvedValue(undefined) },
      verifications: {
        invalidateOpenPasswordResets: jest.fn().mockResolvedValue(undefined),
      },
      sessionsService: { open: jest.fn().mockResolvedValue(TOKENS) },
      verifier: {
        verify: jest.fn().mockResolvedValue({
          subject: 'sub-1',
          email: 'camille@example.com',
          emailVerified: true,
          displayName: null,
          ...claims,
        } satisfies SocialIdentityClaims),
      },
      audit: { record: jest.fn() },
    };

    const config = {
      googleOauthClientIds: audiences.google ?? ['client-google'],
      appleOauthAudiences: audiences.apple ?? ['com.carlys.app'],
    } as AppConfigService;

    const service = new SocialAuthService(
      stubs.users as unknown as UsersRepository,
      stubs.identities as unknown as IdentitiesRepository,
      stubs.sessions as unknown as SessionsRepository,
      stubs.verifications as unknown as VerificationRepository,
      stubs.sessionsService as unknown as SessionsService,
      stubs.verifier as unknown as SocialTokenVerifier,
      stubs.audit as unknown as AuditService,
      config,
    );
    return { service, stubs };
  }

  const requete = { provider: 'google' as const, idToken: 'jwt', devicePlatform: 'android' };

  it('fournisseur non configuré : 503, et le jeton n’est même pas regardé', async () => {
    const { service, stubs } = monter({}, { google: [] });

    await expect(service.login(requete, client)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    // Vérifier un jeton sans audience attendue reviendrait à accepter
    // n'importe quelle audience : la garde doit passer AVANT.
    expect(stubs.verifier.verify).not.toHaveBeenCalled();
  });

  it('chaque fournisseur a ses propres audiences', async () => {
    const { service, stubs } = monter({}, { google: [], apple: ['com.carlys.app'] });

    // Google est coupé, Apple non : l'un ne doit pas activer l'autre.
    await expect(service.login({ ...requete, provider: 'apple' }, client)).resolves.toBeDefined();
    expect(stubs.verifier.verify).toHaveBeenCalledWith('apple', 'jwt', ['com.carlys.app']);
  });

  it('identité connue : session ouverte sur SON compte, sans rien créer', async () => {
    const { service, stubs } = monter();
    stubs.identities.findOwner.mockResolvedValue(utilisateur({ id: 'deja-la' }));

    const result = await service.login(requete, client);

    expect(result.user.id).toBe('deja-la');
    expect(stubs.sessionsService.open).toHaveBeenCalledWith('deja-la', requete, client);
    expect(stubs.users.create).not.toHaveBeenCalled();
    expect(stubs.identities.attach).not.toHaveBeenCalled();
  });

  it('adresse vérifiée d’un compte existant : l’identité s’y rattache', async () => {
    const { service, stubs } = monter();
    stubs.users.findActiveByEmail.mockResolvedValue(utilisateur({ id: 'ancien' }));

    const result = await service.login(requete, client);

    expect(stubs.identities.attach).toHaveBeenCalledWith(
      'ancien',
      ExternalIdentityProvider.GOOGLE,
      'sub-1',
      'camille@example.com',
    );
    expect(result.user.id).toBe('ancien');
    expect(stubs.users.create).not.toHaveBeenCalled();
  });

  it('compte existant jamais vérifié : le fournisseur vient de le prouver', async () => {
    const { service, stubs } = monter();
    stubs.users.findActiveByEmail.mockResolvedValue(
      utilisateur({ id: 'ancien', emailVerifiedAt: null }),
    );
    // Le compte RELU porte la vérification que l'on vient d'écrire.
    stubs.users.findActiveById.mockResolvedValue(
      utilisateur({ id: 'ancien', emailVerifiedAt: new Date('2026-02-02') }),
    );

    const result = await service.login(requete, client);

    expect(stubs.users.markEmailVerified).toHaveBeenCalledWith('ancien');
    // Et la réponse le DIT : présenter le compte lu avant l'écriture
    // annoncerait une adresse non vérifiée juste après l'avoir vérifiée, et
    // le client relancerait une demande de vérification sans objet.
    expect(result.user.emailVerified).toBe(true);
  });

  it('compte jamais vérifié : ce qui pouvait venir d’un TIERS est retiré', async () => {
    // Le pré-enregistrement : n'importe qui peut s'inscrire avec l'adresse
    // d'un autre, le compte étant utilisable sans vérification. Le
    // fournisseur vient de prouver que l'adresse appartient à l'arrivant :
    // le compte lui revient, débarrassé de tout ce qu'un tiers y a laissé.
    const { service, stubs } = monter();
    stubs.users.findActiveByEmail.mockResolvedValue(
      utilisateur({ id: 'pre-enregistre', emailVerifiedAt: null }),
    );
    stubs.users.findActiveById.mockResolvedValue(
      utilisateur({ id: 'pre-enregistre', emailVerifiedAt: new Date('2026-02-02') }),
    );

    await service.login(requete, client);

    expect(stubs.sessions.revokeAllSessions).toHaveBeenCalledWith(
      'pre-enregistre',
      'social_link_unverified_email',
    );
    expect(stubs.users.deleteCredential).toHaveBeenCalledWith('pre-enregistre');
    expect(stubs.verifications.invalidateOpenPasswordResets).toHaveBeenCalledWith('pre-enregistre');
  });

  it('compte DÉJÀ vérifié : on ne retire rien — deux portes, une maison', async () => {
    const { service, stubs } = monter();
    stubs.users.findActiveByEmail.mockResolvedValue(utilisateur({ id: 'ancien' }));

    await service.login(requete, client);

    expect(stubs.sessions.revokeAllSessions).not.toHaveBeenCalled();
    expect(stubs.users.deleteCredential).not.toHaveBeenCalled();
  });

  it('compte suspendu : on n’écrit RIEN avant de refuser', async () => {
    // Rattacher une identité à un compte suspendu, ou lui marquer son
    // adresse vérifiée, reviendrait à modifier un compte auquel on vient
    // précisément d'interdire l'accès.
    const { service, stubs } = monter();
    stubs.users.findActiveByEmail.mockResolvedValue(
      utilisateur({ id: 'suspendu', status: UserStatus.SUSPENDED }),
    );

    await expect(service.login(requete, client)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(stubs.identities.attach).not.toHaveBeenCalled();
    expect(stubs.users.markEmailVerified).not.toHaveBeenCalled();
  });

  it('ADRESSE NON VÉRIFIÉE : ni rattachement, ni création — 401', async () => {
    // Le scénario d'attaque : quelqu'un crée un compte chez un fournisseur
    // laxiste avec l'adresse d'autrui. Sans cette garde, le rattachement lui
    // ouvrirait le compte Carlys de la victime.
    const { service, stubs } = monter({ emailVerified: false });
    stubs.users.findActiveByEmail.mockResolvedValue(utilisateur({ id: 'victime' }));

    await expect(service.login(requete, client)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(stubs.identities.attach).not.toHaveBeenCalled();
    expect(stubs.users.create).not.toHaveBeenCalled();
    expect(stubs.sessionsService.open).not.toHaveBeenCalled();
  });

  it('aucune adresse transmise : refus, sans création de compte fantôme', async () => {
    const { service, stubs } = monter({ email: null });

    await expect(service.login(requete, client)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(stubs.users.create).not.toHaveBeenCalled();
  });

  it('personne : compte créé SANS mot de passe, adresse déjà vérifiée', async () => {
    const { service, stubs } = monter({ displayName: 'Camille G.' });

    const result = await service.login(requete, client);

    const [created] = stubs.users.create.mock.calls[0] ?? [];
    expect(created?.email).toBe('camille@example.com');
    expect(created?.displayName).toBe('Camille G.');
    // Aucune ligne credential : la connexion par mot de passe échouera
    // naturellement, au lieu d'exister avec un hash vide.
    expect(created?.passwordHash).toBeUndefined();
    expect(created?.emailVerifiedAt).toBeInstanceOf(Date);
    expect(stubs.identities.attach).toHaveBeenCalled();
    expect(result.tokens).toEqual(TOKENS);
  });

  it('le nom du client prime : Apple ne le redonne jamais après la première fois', async () => {
    const { service, stubs } = monter({ displayName: 'Depuis le jeton' });

    await service.login({ ...requete, displayName: 'Depuis le SDK' }, client);

    expect(stubs.users.create.mock.calls[0]?.[0]?.displayName).toBe('Depuis le SDK');
  });

  it('sans nom nulle part, la partie locale de l’adresse fait l’affaire', async () => {
    const { service, stubs } = monter({ displayName: null });

    await service.login(requete, client);

    expect(stubs.users.create.mock.calls[0]?.[0]?.displayName).toBe('camille');
  });

  it('l’adresse est normalisée avant toute recherche', async () => {
    const { service, stubs } = monter({ email: '  Camille@EXAMPLE.com ' });

    await service.login(requete, client);

    expect(stubs.users.findActiveByEmail).toHaveBeenCalledWith('camille@example.com');
  });

  it('course entre deux premières connexions : on repart sur l’identité gagnante', async () => {
    const { service, stubs } = monter();
    stubs.users.findActiveByEmail.mockResolvedValue(utilisateur({ id: 'ancien' }));
    // L'autre requête a rattaché l'identité entre notre lecture et notre
    // écriture : la contrainte d'unicité a tranché.
    stubs.identities.attach.mockResolvedValue(false);
    stubs.identities.findOwner
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(utilisateur({ id: 'ancien' }));

    const result = await service.login(requete, client);

    expect(result.user.id).toBe('ancien');
    expect(stubs.sessionsService.open).toHaveBeenCalledTimes(1);
  });

  it('compte suspendu : aucune session, quel que soit le jeton', async () => {
    const { service, stubs } = monter();
    stubs.identities.findOwner.mockResolvedValue(utilisateur({ status: UserStatus.SUSPENDED }));

    await expect(service.login(requete, client)).rejects.toBeInstanceOf(UnauthorizedException);
    expect(stubs.sessionsService.open).not.toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'auth.social_login_blocked' }),
    );
  });

  it('chaque issue laisse sa trace d’audit, fournisseur compris', async () => {
    const { service, stubs } = monter();
    stubs.identities.findOwner.mockResolvedValue(utilisateur());

    await service.login(requete, client);

    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'auth.social_login',
        userId: 'user-1',
        metadata: { provider: 'google' },
      }),
    );
  });
});

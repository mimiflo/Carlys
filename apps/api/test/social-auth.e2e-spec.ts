process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { ExternalIdentityProvider, PrismaClient } from '@prisma/client';
import { createLocalJWKSet, exportJWK, generateKeyPair, type JWK, SignJWT } from 'jose';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { AppConfigService } from '../src/config/app-config.service';
import { type Env } from '../src/config/env.schema';
import { SocialKeyStore } from '../src/modules/auth/application/social-token-verifier';
import { reinitialiserDebit } from './support/throttle';

/**
 * CONNEXION APPLE / GOOGLE, DE BOUT EN BOUT, CONTRE UNE VRAIE BASE.
 *
 * Ce qui est substitué : la seule chose qu'on ne peut pas avoir en test, le
 * TROUSSEAU DE CLÉS PUBLIQUES du fournisseur. Les jetons sont signés pour de
 * bon et vérifiés pour de bon (signature, émetteur, audience, expiration) —
 * c'est le vrai code de vérification qui tourne, pas un passe-droit.
 *
 * Ce qui est éprouvé : à qui la session s'ouvre. Un compte créé sans mot de
 * passe, une identité qui retrouve son compte, une adresse vérifiée qui
 * rattache l'identité au compte e-mail existant — et les refus, dont celui
 * qui compte vraiment : une adresse que le fournisseur ne garantit pas.
 */
describe('Connexion sociale (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let signer: CryptoKey;
  let jwks: { keys: JWK[] };

  const GOOGLE_AUDIENCE = 'carlys-e2e.apps.googleusercontent.com';
  const APPLE_AUDIENCE = 'com.carlys.e2e';

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const errorOf = (body: unknown): ApiErrorEnvelope['error'] => (body as ApiErrorEnvelope).error;
  const emails: string[] = [];

  /** Une adresse neuve, retenue pour le nettoyage de fin de suite. */
  function adresseNeuve(): string {
    const email = `social-${randomUUID()}@carlys.test`;
    emails.push(email);
    return email;
  }

  /** Jeton d'identité réaliste, signé par la clé du trousseau substitué. */
  async function jeton(
    claims: Record<string, unknown>,
    options: { issuer?: string; audience?: string } = {},
  ): Promise<string> {
    return new SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256', kid: 'carlys-e2e' })
      .setIssuer(options.issuer ?? 'https://accounts.google.com')
      .setAudience(options.audience ?? GOOGLE_AUDIENCE)
      .setIssuedAt()
      .setExpirationTime('10m')
      .sign(signer);
  }

  const server = (): request.Agent => request(app.getHttpServer());

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });

    const paire = await generateKeyPair('RS256', { extractable: true });
    signer = paire.privateKey;
    jwks = { keys: [{ ...(await exportJWK(paire.publicKey)), alg: 'RS256', kid: 'carlys-e2e' }] };

    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(SocialKeyStore)
      .useValue({ keyFor: () => createLocalJWKSet(jwks) })
      // Les audiences ne peuvent pas venir de `process.env` : la
      // configuration est validée à l'IMPORT du module, une fois par
      // processus. On prototype donc la vraie configuration — seules les
      // deux listes changent (même procédé que la suite du coach).
      .overrideProvider(AppConfigService)
      .useFactory({
        inject: [ConfigService],
        factory: (config: ConfigService<Env, true>) =>
          Object.create(new AppConfigService(config), {
            googleOauthClientIds: { get: () => [GOOGLE_AUDIENCE] },
            appleOauthAudiences: { get: () => [APPLE_AUDIENCE] },
          }) as AppConfigService,
      })
      .compile();

    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  // `/auth/social` est une route sensible : 10 requêtes par minute et par
  // adresse, comme la connexion. Cette suite en fait davantage à elle seule ;
  // le compteur est donc remis à zéro entre les tests, exactement comme le
  // harnais le fait entre les fichiers. Le quota lui-même reste éprouvé —
  // par le test qui l'atteint DANS un seul test, plus bas.
  beforeEach(reinitialiserDebit);

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('première connexion Google : compte créé, SANS mot de passe, adresse vérifiée', async () => {
    const email = adresseNeuve();
    const sub = `google-${randomUUID()}`;

    const response = await server()
      .post('/api/v1/auth/social')
      .send({
        provider: 'google',
        idToken: await jeton({ sub, email, email_verified: true, name: 'Camille' }),
        devicePlatform: 'android',
      })
      .expect(200);

    const result = data<AuthResult>(response.body);
    expect(result.user.email).toBe(email);
    expect(result.user.displayName).toBe('Camille');
    expect(result.user.emailVerified).toBe(true);
    expect(result.tokens.accessToken.length).toBeGreaterThan(20);

    // Aucune credential : l'état « compte sans mot de passe » est l'ABSENCE
    // de ligne, pas un hash vide qu'on pourrait un jour comparer par erreur.
    const credential = await prisma.userCredential.findUnique({
      where: { userId: result.user.id },
    });
    expect(credential).toBeNull();

    const identity = await prisma.externalIdentity.findUnique({
      where: {
        provider_subject: { provider: ExternalIdentityProvider.GOOGLE, subject: sub },
      },
    });
    expect(identity?.userId).toBe(result.user.id);
  });

  it('la session émise ouvre VRAIMENT les routes authentifiées', async () => {
    const email = adresseNeuve();
    const response = await server()
      .post('/api/v1/auth/social')
      .send({
        provider: 'google',
        idToken: await jeton({ sub: `google-${randomUUID()}`, email, email_verified: true }),
      })
      .expect(200);

    const { tokens } = data<AuthResult>(response.body);
    // Une session sociale n'est pas une session au rabais : c'est la même.
    await server()
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(200);
  });

  it('deuxième connexion : le MÊME compte, jamais un doublon', async () => {
    const email = adresseNeuve();
    const sub = `google-${randomUUID()}`;
    const corps = { provider: 'google', idToken: '' };

    corps.idToken = await jeton({ sub, email, email_verified: true });
    const premier = data<AuthResult>((await server().post('/api/v1/auth/social').send(corps)).body);

    corps.idToken = await jeton({ sub, email, email_verified: true });
    const second = data<AuthResult>(
      (await server().post('/api/v1/auth/social').send(corps).expect(200)).body,
    );

    expect(second.user.id).toBe(premier.user.id);
    expect(await prisma.user.count({ where: { email } })).toBe(1);
  });

  it('adresse d’un compte e-mail existant : l’identité s’y rattache', async () => {
    const email = adresseNeuve();
    const inscription = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'Camille' })
          .expect(201)
      ).body,
    );

    const sub = `google-${randomUUID()}`;
    const social = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/social')
          .send({ provider: 'google', idToken: await jeton({ sub, email, email_verified: true }) })
          .expect(200)
      ).body,
    );

    // Un seul compte, deux façons d'y entrer.
    expect(social.user.id).toBe(inscription.user.id);
    // Le mot de passe existant continue de fonctionner : le rattachement
    // AJOUTE une entrée, il n'en retire aucune.
    await server()
      .post('/api/v1/auth/login')
      .send({ email, password: 'MotDePasseSolide42' })
      .expect(200);
    // Et l'adresse, jusque-là non vérifiée, l'est désormais : le fournisseur
    // vient d'en prouver la propriété.
    expect(social.user.emailVerified).toBe(true);
  });

  it('adresse NON vérifiée par le fournisseur : 401, aucun compte touché', async () => {
    const email = adresseNeuve();
    await server()
      .post('/api/v1/auth/register')
      .send({ email, password: 'MotDePasseSolide42', displayName: 'Camille' })
      .expect(201);

    const response = await server()
      .post('/api/v1/auth/social')
      .send({
        provider: 'google',
        idToken: await jeton({ sub: `google-${randomUUID()}`, email, email_verified: false }),
      })
      .expect(401);

    expect(errorOf(response.body).message).toContain('adresse e-mail');
    expect(
      await prisma.externalIdentity.count({
        where: { user: { email } },
      }),
    ).toBe(0);
  });

  it('jeton d’une AUTRE application : 401', async () => {
    const response = await server()
      .post('/api/v1/auth/social')
      .send({
        provider: 'google',
        idToken: await jeton(
          { sub: 'x', email: adresseNeuve(), email_verified: true },
          { audience: 'application-de-quelquun-dautre' },
        ),
      })
      .expect(401);

    expect(errorOf(response.body).message).toContain('Google');
  });

  it('jeton Apple présenté comme Google : 401 (émetteur croisé)', async () => {
    await server()
      .post('/api/v1/auth/social')
      .send({
        provider: 'google',
        idToken: await jeton(
          { sub: 'x', email: adresseNeuve(), email_verified: true },
          { issuer: 'https://appleid.apple.com', audience: APPLE_AUDIENCE },
        ),
      })
      .expect(401);
  });

  it('Apple : email_verified en chaîne, et le nom vient du client', async () => {
    const email = adresseNeuve();
    const response = await server()
      .post('/api/v1/auth/social')
      .send({
        provider: 'apple',
        // Apple ne met jamais le nom dans le jeton : le SDK le transmet à la
        // première connexion, et jamais ensuite.
        idToken: await jeton(
          { sub: `apple-${randomUUID()}`, email, email_verified: 'true' },
          { issuer: 'https://appleid.apple.com', audience: APPLE_AUDIENCE },
        ),
        displayName: 'Camille depuis Apple',
      })
      .expect(200);

    const result = data<AuthResult>(response.body);
    expect(result.user.displayName).toBe('Camille depuis Apple');
    expect(result.user.emailVerified).toBe(true);
  });

  it('la route est bien BRIDÉE : au-delà du quota, 429', async () => {
    // Une route d'authentification publique est une cible d'énumération. Le
    // quota strict (10/min) doit s'y appliquer comme à la connexion — ce
    // test l'atteint dans un seul test, hors de portée du nettoyage.
    const email = adresseNeuve();
    const corps = {
      provider: 'google',
      idToken: await jeton({ sub: `google-${randomUUID()}`, email, email_verified: true }),
    };

    let refus = 0;
    for (let essai = 0; essai < 12; essai += 1) {
      const { status } = await server().post('/api/v1/auth/social').send(corps);
      if (status === 429) refus += 1;
    }

    expect(refus).toBeGreaterThan(0);
  });

  it('corps invalide : 400, jamais une erreur serveur', async () => {
    await server()
      .post('/api/v1/auth/social')
      .send({ provider: 'facebook', idToken: 'peu importe' })
      .expect(400);

    await server().post('/api/v1/auth/social').send({ provider: 'google' }).expect(400);
  });

  describe('fournisseur non configuré', () => {
    let sansGoogle: INestApplication<App>;

    beforeAll(async () => {
      const fixture = await Test.createTestingModule({ imports: [AppModule] })
        .overrideProvider(SocialKeyStore)
        .useValue({ keyFor: () => createLocalJWKSet(jwks) })
        .overrideProvider(AppConfigService)
        .useFactory({
          inject: [ConfigService],
          factory: (config: ConfigService<Env, true>) =>
            Object.create(new AppConfigService(config), {
              googleOauthClientIds: { get: () => [] },
              appleOauthAudiences: { get: () => [] },
            }) as AppConfigService,
        })
        .compile();
      sansGoogle = fixture.createNestApplication<NestExpressApplication>();
      configureApp(sansGoogle as NestExpressApplication);
      await sansGoogle.init();
    });

    afterAll(async () => {
      await sansGoogle.close();
    });

    it('503 explicite — le client peut le DIRE au lieu d’afficher une panne', async () => {
      const response = await request(sansGoogle.getHttpServer())
        .post('/api/v1/auth/social')
        .send({
          provider: 'google',
          idToken: await jeton({ sub: 'x', email: adresseNeuve(), email_verified: true }),
        })
        .expect(503);

      // Le filtre d'exceptions masque le MESSAGE de toute 5xx — c'est la
      // règle du dépôt, aucune fuite d'interne. Ce que le client lit, et ce
      // sur quoi il doit se brancher, c'est le CODE de l'enveloppe.
      expect(errorOf(response.body).code).toBe('SERVICE_UNAVAILABLE');
    });
  });
});

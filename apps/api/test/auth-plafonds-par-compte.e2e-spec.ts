process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  ACADEMY_LESSON_IDS,
  type ApiSuccessEnvelope,
  type AuthResult,
  type League,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
import { type Server } from 'node:http';
import { type AddressInfo } from 'node:net';
import request from 'supertest';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { AppConfigService } from '../src/config/app-config.service';
import { type Env } from '../src/config/env.schema';
import { EmailService, LINKS_PER_ADDRESS } from '../src/infrastructure/email/email.service';
import { ENCOURAGEMENTS_PER_FRIEND_PER_DAY } from '../src/modules/community/application/encouragements.service';
import { reauthLockoutKey } from '../src/modules/auth/application/reauthentication.service';

const PASSWORD = 'MotDePasseSolide42';
/** AUTH_MAX_LOGIN_ATTEMPTS par défaut. */
const SEUIL = 5;
/** Assez d'adresses pour qu'aucune limite PAR IP ne joue : seul le plafond par compte reste. */
const RAFALE = 30;

/**
 * Les plafonds PAR COMPTE tiennent face à une RAFALE venue de 30 adresses IP :
 * connexion mobile, connexion du back-office, re-authentification, demande de
 * réinitialisation, renvoi du lien de vérification, encouragements, bonnes
 * réponses de quiz créditées.
 *
 * C'est le scénario qu'ils existent pour arrêter : la limite par IP se
 * contourne en multipliant les adresses, le plafond par compte ne doit pas se
 * contourner en multipliant les requêtes SIMULTANÉES. Avant correctif, le
 * verrouillage LISAIT le compteur, vérifiait le mot de passe, puis seulement
 * COMPTAIT l'échec : 30 essais parallèles voyaient tous « non verrouillé »,
 * et 14 d'entre eux faisaient vérifier leur mot de passe au lieu de 5 (23 sur
 * 60). Et la demande de réinitialisation n'avait aucune cadence par compte :
 * 30 appels, 30 courriers réels vers la même adresse en moins d'une minute.
 *
 * L'application fait confiance à un saut de proxy (comme en production
 * derrière nginx) : chaque requête annonce sa propre adresse, et écoute sur un
 * vrai port pour que les requêtes partent réellement en parallèle.
 */
describe('Plafonds par compte face à une rafale multi-IP (e2e)', () => {
  let app: INestApplication;
  let url: string;
  let prisma: PrismaClient;
  let redis: Redis;
  const userIds: string[] = [];
  const emails: string[] = [];
  const reinitialisationsEnvoyees: string[] = [];
  const adminEmail = `e2e-plafonds-admin-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  /** Une adresse de documentation distincte par requête (RFC 5737). */
  const ip = (i: number) => `198.51.100.${i + 1}`;

  const register = async (name: string): Promise<AuthResult & { email: string }> => {
    const email = `e2e-plafonds-${name}-${randomUUID()}@carlys.test`;
    emails.push(email);
    const result = data<AuthResult>(
      (
        await request(url)
          .post('/api/v1/auth/register')
          // Une adresse par inscription : la limite stricte par IP (10 par
          // minute) ne doit pas borner le nombre de comptes de la suite.
          .set('X-Forwarded-For', `192.0.2.${userIds.length + 1}`)
          .send({ email, password: PASSWORD, displayName: name })
          .expect(201)
      ).body,
    );
    userIds.push(result.user.id);
    return { ...result, email };
  };

  const rafale = async (envoi: (i: number) => request.Test): Promise<number[]> => {
    const reponses = await Promise.all(Array.from({ length: RAFALE }, (_, i) => envoi(i)));
    return reponses.map((reponse) => reponse.status);
  };
  const compter = (statuts: number[], statut: number) => statuts.filter((s) => s === statut).length;

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(AppConfigService)
      .useFactory({
        inject: [ConfigService],
        factory: (config: ConfigService<Env, true>) =>
          Object.create(new AppConfigService(config), {
            trustProxyHops: { get: () => 1 },
          }) as AppConfigService,
      })
      .compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.listen(0, '127.0.0.1');
    const { port } = (app.getHttpServer() as Server).address() as AddressInfo;
    url = `http://127.0.0.1:${port}`;
    jest
      .spyOn(app.get(EmailService), 'sendPasswordReset')
      .mockImplementation((_to: string, token: string) => {
        reinitialisationsEnvoyees.push(token);
      });
  });

  afterAll(async () => {
    // L'application se ferme d'abord : ses écritures d'audit en vol sont
    // drainées avant le nettoyage (voir admin-lockout.e2e-spec.ts).
    await app.close();
    await prisma.auditLog.deleteMany({ where: { adminUser: { email: adminEmail } } });
    await prisma.adminUser.deleteMany({ where: { email: adminEmail } });
    await redis.del(`auth:lockout:admin:${adminEmail}`);
    for (const id of userIds) {
      await redis.del(`auth:lockout:${reauthLockoutKey(id)}`);
    }
    for (const email of emails) {
      await redis.del(`auth:lockout:${email}`);
    }
    await redis.quit();
    await prisma.user.deleteMany({ where: { id: { in: userIds } } });
    await prisma.$disconnect();
  });

  it('change-password : 30 mauvais essais simultanés, 5 vérifiés au plus, le reste en 429', async () => {
    const u = await register('reauth');
    const statuts = await rafale((i) =>
      request(url)
        .post('/api/v1/auth/change-password')
        .set('X-Forwarded-For', ip(i))
        .set('Authorization', `Bearer ${u.tokens.accessToken}`)
        .send({ currentPassword: `Faux-${i}-motdepasse`, newPassword: 'NouveauMotDePasse42' }),
    );
    expect(compter(statuts, 401)).toBe(SEUIL);
    expect(compter(statuts, 429)).toBe(RAFALE - SEUIL);
  });

  it('la réinitialisation du mot de passe libère AUSSI les re-authentifications', async () => {
    // Le voleur d'une session épuise le plafond de re-authentification ; le
    // propriétaire reprend la main par « Mot de passe oublié ». Il a prouvé
    // qu'il tient la boîte mail : supprimer son compte, avec le bon mot de
    // passe, ne doit pas lui répondre 429 jusqu'à la fin de la fenêtre.
    const u = await register('reprise');
    const statuts = await rafale((i) =>
      request(url)
        .post('/api/v1/auth/change-password')
        .set('X-Forwarded-For', ip(i))
        .set('Authorization', `Bearer ${u.tokens.accessToken}`)
        .send({ currentPassword: `Faux-${i}-motdepasse`, newPassword: 'NouveauMotDePasse42' }),
    );
    expect(compter(statuts, 429)).toBe(RAFALE - SEUIL);

    await request(url)
      .post('/api/v1/auth/forgot-password')
      .set('X-Forwarded-For', ip(0))
      .send({ email: u.email })
      .expect(202);
    const nouveau = 'ApresReinitialisation42';
    await request(url)
      .post('/api/v1/auth/reset-password')
      .set('X-Forwarded-For', ip(1))
      .send({ token: reinitialisationsEnvoyees.at(-1), newPassword: nouveau })
      .expect(204);
    const reconnecte = data<AuthResult>(
      (
        await request(url)
          .post('/api/v1/auth/login')
          .set('X-Forwarded-For', ip(2))
          .send({ email: u.email, password: nouveau })
          .expect(200)
      ).body,
    );
    await request(url)
      .delete('/api/v1/users/me')
      .set('X-Forwarded-For', ip(3))
      .set('Authorization', `Bearer ${reconnecte.tokens.accessToken}`)
      .send({ password: nouveau })
      .expect(204);
  });

  it('inscription puis suppression en boucle : pas plus de liens vers une adresse que son plafond', async () => {
    // Supprimer un compte libère aussitôt son adresse ; chaque inscription
    // repartait donc d'une cadence neuve. Mesuré avant le plafond par
    // adresse : 8 tours, 8 courriers vers la victime.
    const service = app.get(EmailService);
    const transporteur = (
      service as unknown as {
        transporter: { sendMail: (mail: { to: string }) => Promise<unknown> };
      }
    ).transporter;
    const envoi = jest.spyOn(transporteur, 'sendMail').mockResolvedValue({});
    const victime = `e2e-plafonds-victime-${randomUUID()}@carlys.test`;
    try {
      for (let tour = 0; tour < 8; tour += 1) {
        const compte = data<AuthResult>(
          (
            await request(url)
              .post('/api/v1/auth/register')
              .set('X-Forwarded-For', ip(100 + tour))
              .send({ email: victime, password: PASSWORD, displayName: 'Tour' })
              .expect(201)
          ).body,
        );
        userIds.push(compte.user.id);
        await request(url)
          .delete('/api/v1/users/me')
          .set('X-Forwarded-For', ip(100 + tour))
          .set('Authorization', `Bearer ${compte.tokens.accessToken}`)
          .send({ password: PASSWORD })
          .expect(204);
      }
      await service.flush();
      const versVictime = envoi.mock.calls.filter(([mail]) => mail.to === victime);
      expect(versVictime).toHaveLength(LINKS_PER_ADDRESS);
    } finally {
      envoi.mockRestore();
    }
  });

  it('login : même rafale, même plafond', async () => {
    const u = await register('connexion');
    const statuts = await rafale((i) =>
      request(url)
        .post('/api/v1/auth/login')
        .set('X-Forwarded-For', ip(i))
        .send({ email: u.email, password: `Faux-${i}-motdepasse` }),
    );
    expect(compter(statuts, 401)).toBe(SEUIL);
    expect(compter(statuts, 429)).toBe(RAFALE - SEUIL);
  });

  it('connexion du back-office : même rafale, même plafond', async () => {
    // Le verrouillage n'exige aucun rôle : un compte nu suffit.
    await prisma.adminUser.create({
      data: {
        email: adminEmail,
        displayName: 'Admin plafonds E2E',
        passwordHash: await argon2.hash(PASSWORD, { type: argon2.argon2id }),
      },
    });
    const statuts = await rafale((i) =>
      request(url)
        .post('/api/v1/admin/auth/login')
        .set('X-Forwarded-For', ip(i))
        .send({ email: adminEmail, password: `Faux-${i}-motdepasse` }),
    );
    expect(compter(statuts, 401)).toBe(SEUIL);
    expect(compter(statuts, 429)).toBe(RAFALE - SEUIL);
  });

  it('forgot-password : 30 demandes simultanées, un seul lien, puis cadence et plafond par compte', async () => {
    const u = await register('oubli');
    const liens = () =>
      prisma.passwordReset.findMany({
        where: { userId: u.user.id },
        orderBy: { createdAt: 'asc' },
      });
    const demander = (i: number) =>
      request(url)
        .post('/api/v1/auth/forgot-password')
        .set('X-Forwarded-For', ip(i))
        .send({ email: u.email });
    const avant = reinitialisationsEnvoyees.length;

    // Réponse identique pour tous (aucune énumération), un seul courrier.
    const statuts = await rafale(demander);
    expect(compter(statuts, 202)).toBe(RAFALE);
    expect(await liens()).toHaveLength(1);
    expect(reinitialisationsEnvoyees.length).toBe(avant + 1);

    // Le délai minimal passé, un nouveau lien part. Le précédent RESTE
    // valable : une demande anonyme ne casse pas le lien de quelqu'un.
    await prisma.passwordReset.updateMany({
      where: { userId: u.user.id },
      data: { createdAt: new Date(Date.now() - 120_000) },
    });
    const premier = reinitialisationsEnvoyees.at(-1);
    await demander(0).expect(202);
    const apres = await liens();
    expect(apres).toHaveLength(2);
    expect(apres.filter((lien) => lien.usedAt === null)).toHaveLength(2);
    expect(reinitialisationsEnvoyees.length).toBe(avant + 2);

    // Cinq liens par fenêtre (la validité d'un lien, 60 min par défaut) au
    // plus, même une fois le délai minimal passé.
    await prisma.passwordReset.createMany({
      data: [1, 2, 3].map((i) => ({
        userId: u.user.id,
        tokenHash: `e2e-plafond-reinit-${randomUUID()}-${i}`,
        expiresAt: new Date(Date.now() + 600_000),
      })),
    });
    await prisma.passwordReset.updateMany({
      where: { userId: u.user.id },
      data: { createdAt: new Date(Date.now() - 10 * 60_000) },
    });
    await demander(2).expect(202);
    expect(await liens()).toHaveLength(5);
    expect(reinitialisationsEnvoyees.length).toBe(avant + 2);

    // Un refus n'est jamais une impasse : le lien arrivé le premier sert
    // encore, et le servir fait tomber tous les autres.
    await request(url)
      .post('/api/v1/auth/reset-password')
      .set('X-Forwarded-For', ip(1))
      .send({ token: premier, newPassword: 'NouveauMotDePasse42' })
      .expect(204);
    expect((await liens()).filter((lien) => lien.usedAt === null)).toHaveLength(0);

    // La fenêtre écoulée, la demande repart.
    await prisma.passwordReset.updateMany({
      where: { userId: u.user.id },
      data: { createdAt: new Date(Date.now() - 61 * 60_000) },
    });
    await demander(3).expect(202);
    expect(await liens()).toHaveLength(6);
    expect(reinitialisationsEnvoyees.length).toBe(avant + 3);
  });

  /**
   * Trois plafonds tenus par un VERROU « compter puis écrire » (`lockNamed`).
   * Des requêtes l'une après l'autre ne peuvent pas voir ce verrou
   * disparaître ; seule une rafale le peut. Mesuré sans verrou : 21 à 24
   * encouragements pour un plafond de 20, 4 à 7 liens de vérification actifs
   * au lieu d'un, 30 à 70 points de quiz au lieu de 30.
   */
  it('renvoi du lien de vérification : 20 renvois simultanés, un seul lien actif', async () => {
    const u = await register('verif');
    // Le délai minimal depuis le premier lien, passé.
    await prisma.emailVerification.updateMany({
      where: { userId: u.user.id },
      data: { createdAt: new Date(Date.now() - 120_000) },
    });
    const statuts = await Promise.all(
      Array.from({ length: 20 }, (_, i) =>
        request(url)
          .post('/api/v1/auth/resend-verification')
          .set('X-Forwarded-For', ip(i))
          .set('Authorization', `Bearer ${u.tokens.accessToken}`)
          .then((reponse) => reponse.status),
      ),
    );
    expect(compter(statuts, 204)).toBe(20);
    const liens = await prisma.emailVerification.findMany({ where: { userId: u.user.id } });
    expect(liens).toHaveLength(2);
    expect(liens.filter((lien) => lien.usedAt === null)).toHaveLength(1);
  });

  it(`encouragements : ${RAFALE} envois simultanés au même ami, ${ENCOURAGEMENTS_PER_FRIEND_PER_DAY} écrits au plus`, async () => {
    const a = await register('encourage-a');
    const b = await register('encourage-b');
    const en = (token: string, i: number) => ({
      get: (chemin: string) =>
        request(url)
          .get(chemin)
          .set('X-Forwarded-For', ip(i))
          .set('Authorization', `Bearer ${token}`),
      post: (chemin: string) =>
        request(url)
          .post(chemin)
          .set('X-Forwarded-For', ip(i))
          .set('Authorization', `Bearer ${token}`),
    });
    await en(a.tokens.accessToken, 0)
      .post('/api/v1/community/requests')
      .send({ email: b.email })
      .expect(202);
    const recues = data<Array<{ id: string }>>(
      (await en(b.tokens.accessToken, 1).get('/api/v1/community/requests').expect(200)).body,
    );
    await en(b.tokens.accessToken, 1)
      .post(`/api/v1/community/requests/${recues[0]?.id}/accept`)
      .expect(204);

    await rafale((i) =>
      en(a.tokens.accessToken, i)
        .post('/api/v1/community/encouragements')
        .send({ recipientUserId: b.user.id, message: 'Allez !' }),
    );
    expect(
      await prisma.encouragement.count({ where: { senderId: a.user.id, recipientId: b.user.id } }),
    ).toBe(ENCOURAGEMENTS_PER_FRIEND_PER_DAY);
  });

  it('quiz : 20 bonnes réponses simultanées ne créditent que 3 × 10 points', async () => {
    const u = await register('quiz');
    const en = (i: number) => ({
      get: (chemin: string) =>
        request(url)
          .get(chemin)
          .set('X-Forwarded-For', ip(i))
          .set('Authorization', `Bearer ${u.tokens.accessToken}`),
      post: (chemin: string) =>
        request(url)
          .post(chemin)
          .set('X-Forwarded-For', ip(i))
          .set('Authorization', `Bearer ${u.tokens.accessToken}`),
    });
    await en(0).post('/api/v1/community/league/join').expect(201);
    const jour = new Date().toISOString().slice(0, 10);
    const statuts = await Promise.all(
      ACADEMY_LESSON_IDS.slice(0, 20).map((lessonId, i) =>
        en(i)
          .post('/api/v1/community/quiz-answers')
          .send({ lessonId, answeredOn: jour, correct: true })
          .then((reponse) => reponse.status),
      ),
    );
    expect(compter(statuts, 204)).toBe(20);
    const ligue = data<League>((await en(0).get('/api/v1/community/league').expect(200)).body);
    expect(ligue.score).toBe(30);
    // Toutes les réponses sont gardées : la progression de l'Académie les relit.
    expect(await prisma.quizAnswer.count({ where: { userId: u.user.id } })).toBe(20);
  });
});

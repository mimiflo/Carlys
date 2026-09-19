process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiSuccessEnvelope, type AuthResult, type League } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';

/**
 * LES LIGUES : un classement hebdomadaire, CHOISI, qui ne rend rien au profil.
 *
 * Ce qui se vérifie ici : rien n'est compté tant qu'on n'a pas rejoint (le
 * « périmètre choisi » du principe 5), l'effort se convertit selon le barème
 * au lieu de s'additionner brut, et une période échue se règle À LA LECTURE,
 * sans tâche planifiée.
 */
describe('Ligues (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  let userId: string;
  const email = `e2e-league-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (bearer: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${bearer}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${bearer}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${bearer}`),
  });

  /** Une séance de course de `metres`, du début à la clôture. */
  const courir = async (metres: number) => {
    const sessionId = randomUUID();
    await as(token)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: new Date().toISOString() })
      .expect(201);
    await as(token)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseName: 'Course',
        position: 0,
        distanceMeters: metres,
        completedAt: new Date().toISOString(),
      })
      .expect(201);
    await as(token).post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200);
  };

  const ligue = async () =>
    data<League>((await as(token).get('/api/v1/community/league').expect(200)).body);

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const inscrite = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'Ligueuse' })
          .expect(201)
      ).body,
    );
    token = inscrite.tokens.accessToken;
    userId = inscrite.user.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  it('sans adhésion, rien n’est compté et le classement est VIDE', async () => {
    const avant = await ligue();
    expect(avant.joined).toBe(false);
    expect(avant.division).toBe('BRONZE');
    expect(avant.standings).toEqual([]);

    // Une séance faite AVANT d'avoir rejoint ne crée aucune ligne : c'est le
    // « périmètre CHOISI » — on n'est classé qu'après avoir dit oui.
    await courir(5_000);
    expect(await prisma.leagueMembership.count({ where: { userId } })).toBe(0);
  });

  it('rejoindre ouvre la période, et l’effort s’y convertit en POINTS', async () => {
    const entree = data<League>(
      (await as(token).post('/api/v1/community/league/join').expect(201)).body,
    );
    expect(entree.joined).toBe(true);
    expect(entree.score).toBe(0);
    expect(entree.periodKey).toMatch(/^\d{4}-W\d{2}$/);

    // Une séance de 5 km : 50 points pour la séance, 50 pour les 5 000 m
    // (un point par tranche de 100). Les mètres bruts écraseraient les
    // séances de deux ordres de grandeur — c'est tout l'objet du barème.
    await courir(5_000);
    const apres = await ligue();
    expect(apres.score).toBe(100);
    expect(apres.standings.find((ligne) => ligne.isMe)?.score).toBe(100);
    expect(apres.standings.find((ligne) => ligne.isMe)?.rank).toBe(1);
  });

  it('le reste d’une conversion n’est JAMAIS reporté', async () => {
    const avant = (await ligue()).score;
    // 149 mètres : un point, pas 1,49. Le reste n'est pas gardé pour la
    // prochaine séance — le reporter rendrait le score dépendant de l'ordre
    // des écritures.
    await courir(149);
    expect((await ligue()).score).toBe(avant + 51);
  });

  it('une période échue se règle À LA LECTURE, et la montée survit', async () => {
    // La semaine passée, seule au classement : moins de dix joueurs, donc
    // personne ne bouge — un classement à une personne ne décide de rien.
    const semaineEchue = '2026-W01';
    await prisma.leagueMembership.create({
      data: { userId, periodKey: semaineEchue, division: 'ARGENT', score: 320 },
    });

    const vue = await ligue();

    const reglee = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId, periodKey: semaineEchue } },
    });
    expect(reglee.settledAt).not.toBeNull();
    expect(reglee.finalRank).toBe(1);
    expect(reglee.nextDivision).toBe('ARGENT');
    expect(vue.lastResult).toEqual({
      periodKey: semaineEchue,
      rank: 1,
      from: 'ARGENT',
      to: 'ARGENT',
    });

    // Relire ne règle pas deux fois : l'écriture est conditionnée à
    // `settledAt: null`, et le résultat n'est annoncé qu'une fois.
    expect((await ligue()).lastResult).toBeNull();
  });

  it('un effort arrivé APRÈS le règlement ne fait plus bouger le classement', async () => {
    const figee = await prisma.leagueMembership.findFirstOrThrow({
      where: { userId, settledAt: { not: null } },
    });
    const avant = figee.score;

    // Le dépôt refuse d'écrire sur une période réglée : un classement déjà
    // annoncé ne se corrige pas parce qu'une séance se synchronise en retard.
    await prisma.leagueMembership.updateMany({
      where: { userId, periodKey: figee.periodKey, settledAt: null },
      data: { score: { increment: 500 } },
    });
    const apres = await prisma.leagueMembership.findUniqueOrThrow({
      where: { userId_periodKey: { userId, periodKey: figee.periodKey } },
    });
    expect(apres.score).toBe(avant);
  });

  it('sortir arrête le compte, sans effacer la semaine en cours', async () => {
    const avant = (await ligue()).score;
    const sortie = data<League>(
      (await as(token).delete('/api/v1/community/league/join').expect(200)).body,
    );
    expect(sortie.joined).toBe(false);
    expect(sortie.standings).toEqual([]);

    await courir(5_000);
    // La ligne de la semaine existe toujours, avec son score d'avant : la
    // sortie arrête le compte, elle ne réécrit pas le passé.
    const courante = await prisma.leagueMembership.findFirstOrThrow({
      where: { userId, settledAt: null },
      orderBy: { periodKey: 'desc' },
    });
    expect(courante.score).toBe(avant);
  });
});

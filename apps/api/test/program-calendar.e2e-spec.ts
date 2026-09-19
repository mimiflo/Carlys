process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type ProgramCalendarWeek,
  type ProgramDetail,
  type WorkoutSessionDetail,
} from '@carlys/api-contracts';
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
 * LE CALENDRIER DATÉ : ce que le programme devient quand il a une origine.
 *
 * Rien n'est stocké de son état. « Fait » découle du lien séance → jour,
 * « manqué » de la date dans le fuseau de la personne, « hors période » du
 * jour de départ réel. Ces épreuves vérifient les trois déductions, et
 * surtout ce qu'elles refusent de dire.
 */
describe('Calendrier de programme (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  let otherToken: string;
  let templateId: string;
  const email = `e2e-cal-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-cal-autre-${randomUUID()}@carlys.test`;
  const programId = randomUUID();
  const jours = {
    lundiS1: randomUUID(),
    mercrediS1: randomUUID(),
    dimancheS1: randomUUID(),
    lundiS2: randomUUID(),
  };

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (bearer: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${bearer}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${bearer}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${bearer}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${bearer}`),
  });

  /**
   * L'arithmétique de jours civils du test, écrite À PART de celle du
   * serveur : si les deux partageaient leur code, elles se tromperaient
   * ensemble sans que rien ne le dise.
   */
  const midi = (dayKey: string) => new Date(`${dayKey}T12:00:00Z`);
  const plusJours = (dayKey: string, days: number) => {
    const jour = midi(dayKey);
    jour.setUTCDate(jour.getUTCDate() + days);
    return jour.toISOString().slice(0, 10);
  };
  const lundiDe = (dayKey: string) => plusJours(dayKey, 1 - (midi(dayKey).getUTCDay() || 7));

  const calendrier = async (query = ''): Promise<ProgramCalendarWeek> =>
    data<ProgramCalendarWeek>(
      (await as(token).get(`/api/v1/programs/${programId}/calendar${query}`).expect(200)).body,
    );

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = async (mail: string) =>
      data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({ email: mail, password: 'MotDePasseSolide42', displayName: 'Membre E2E' })
            .expect(201)
        ).body,
      ).tokens.accessToken;
    token = await register(email);
    otherToken = await register(otherEmail);

    templateId = randomUUID();
    await as(token)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send({
        name: 'Push A',
        exercises: [
          { id: randomUUID(), exerciseName: 'Développé couché', sets: [{ id: randomUUID() }] },
        ],
      })
      .expect(201);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [email, otherEmail] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('sans date de début, le calendrier se REFUSE en le disant', async () => {
    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Prise de masse', weeksCount: 3, days: [] })
      .expect(201);

    // 400 nommé, jamais une semaine vide : « pas encore de date de début »
    // se corrige en deux gestes, « aucune séance » ne se corrige pas.
    const refus = await as(token).get(`/api/v1/programs/${programId}/calendar`).expect(400);
    expect(JSON.stringify(refus.body)).toContain('date de début');

    const detail = data<ProgramDetail>(
      (await as(token).get(`/api/v1/programs/${programId}`).expect(200)).body,
    );
    expect(detail.startsOn).toBeNull();
  });

  it('date le plan depuis le LUNDI, et laisse hors période ce qui précède le départ', async () => {
    // On a besoin du jour civil vu par le SERVEUR, dans le fuseau de la
    // personne : le test ne décide pas de ce qu'est « aujourd'hui ».
    const sonde = await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Prise de masse', weeksCount: 3, startsOn: '2026-01-05', days: [] })
      .expect(200);
    expect(data<ProgramDetail>(sonde.body).startsOn).toBe('2026-01-05');
    const aujourdHui = (await calendrier('?week=1')).today;

    // Semaine 1 ENTIÈREMENT passée, semaine 2 en cours : le départ est le
    // MERCREDI de la semaine dernière, donc lundi et mardi le précèdent.
    const lundiDernier = lundiDe(plusJours(aujourdHui, -7));
    const startsOn = plusJours(lundiDernier, 2);

    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({
        name: 'Prise de masse',
        weeksCount: 3,
        startsOn,
        days: [
          { id: jours.lundiS1, weekNumber: 1, dayOfWeek: 1, templateId },
          { id: jours.mercrediS1, weekNumber: 1, dayOfWeek: 3, templateId },
          { id: jours.dimancheS1, weekNumber: 1, dayOfWeek: 7, isRest: true },
          { id: jours.lundiS2, weekNumber: 2, dayOfWeek: 1, templateId },
        ],
      })
      .expect(200);

    const semaine = await calendrier('?week=1');
    expect(semaine.startsOn).toBe(startsOn);
    // SEPT jours, toujours : un calendrier qui saute les jours vides n'est
    // plus un calendrier.
    expect(semaine.days).toHaveLength(7);
    expect(semaine.days[0]?.date).toBe(lundiDernier);
    expect(semaine.days[6]?.date).toBe(plusJours(lundiDernier, 6));

    // Le lundi précède le départ : ni fait, ni manqué — hors période. Sans
    // cette nuance, la première ouverture accueillerait par des cases rouges
    // des séances que personne n'avait promis de faire.
    expect(semaine.days[0]?.status).toBe('before');
    // Le mercredi est le jour du départ, il est passé et rien n'a été fait.
    expect(semaine.days[2]?.status).toBe('missed');
    // Le mardi n'a aucune case : rien n'était prévu, rien n'est reproché.
    expect(semaine.days[1]).toMatchObject({ id: null, status: 'free' });
    expect(semaine.days[6]?.status).toBe('rest');
  });

  it('ouvre sur la semaine d’AUJOURD’HUI quand on ne demande rien', async () => {
    const semaine = await calendrier();
    // Trois semaines après le départ, personne ne veut relire la semaine 1.
    expect(semaine.currentWeek).toBe(2);
    expect(semaine.weekNumber).toBe(2);
    expect(semaine.days.some((jour) => jour.date === semaine.today)).toBe(true);
  });

  it('une séance TERMINÉE coche sa case, et la suppression la décoche', async () => {
    const sessionId = randomUUID();
    const session = data<WorkoutSessionDetail>(
      (
        await as(token)
          .post('/api/v1/workout-sessions')
          .send({
            id: sessionId,
            startedAt: new Date().toISOString(),
            templateId,
            programDayId: jours.mercrediS1,
          })
          .expect(201)
      ).body,
    );
    expect(session.programDayId).toBe(jours.mercrediS1);

    // EN COURS ne coche rien : une séance commencée n'est pas une séance
    // faite.
    expect((await calendrier('?week=1')).days[2]?.status).toBe('missed');

    await as(token).post(`/api/v1/workout-sessions/${sessionId}/complete`).expect(200);
    const faite = (await calendrier('?week=1')).days[2];
    expect(faite?.status).toBe('done');
    expect(faite?.sessionId).toBe(sessionId);

    // Réécrire le programme DÉTRUIT puis recrée ses jours : le lien tient
    // parce qu'il porte sur l'identifiant, stable d'une écriture à l'autre.
    // C'est exactement pourquoi la colonne n'a PAS de clé étrangère.
    const startsOn = (await calendrier('?week=1')).startsOn;
    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({
        name: 'Prise de masse v2',
        weeksCount: 3,
        startsOn,
        days: [
          { id: jours.lundiS1, weekNumber: 1, dayOfWeek: 1, templateId },
          { id: jours.mercrediS1, weekNumber: 1, dayOfWeek: 3, templateId },
          { id: jours.dimancheS1, weekNumber: 1, dayOfWeek: 7, isRest: true },
          { id: jours.lundiS2, weekNumber: 2, dayOfWeek: 1, templateId },
        ],
      })
      .expect(200);
    expect((await calendrier('?week=1')).days[2]?.status).toBe('done');

    // La suppression est LOGIQUE : sans le filtre `deletedAt`, la case
    // brillerait encore pour une séance effacée. Aucune route HTTP ne
    // supprime une séance aujourd'hui — l'effacement se pose donc en base,
    // ce qui est exactement ce que le filtre doit voir.
    await prisma.workoutSession.update({
      where: { id: sessionId },
      data: { deletedAt: new Date() },
    });
    expect((await calendrier('?week=1')).days[2]?.status).toBe('missed');
  });

  it('un jour inconnu ou venu d’autrui se perd en SILENCE, la séance jamais', async () => {
    // La file de synchronisation traite un 4xx comme DÉFINITIF : refuser
    // ici perdrait le travail réel pour une case de calendrier.
    const inconnue = data<WorkoutSessionDetail>(
      (
        await as(token)
          .post('/api/v1/workout-sessions')
          .send({
            id: randomUUID(),
            startedAt: new Date().toISOString(),
            programDayId: randomUUID(),
          })
          .expect(201)
      ).body,
    );
    expect(inconnue.programDayId).toBeNull();

    // Le jour d'autrui ne se lie pas davantage — et ne se signale pas.
    const volee = data<WorkoutSessionDetail>(
      (
        await as(otherToken)
          .post('/api/v1/workout-sessions')
          .send({
            id: randomUUID(),
            startedAt: new Date().toISOString(),
            programDayId: jours.mercrediS1,
          })
          .expect(201)
      ).body,
    );
    expect(volee.programDayId).toBeNull();
  });

  it('refuse une semaine hors du plan, et le calendrier d’autrui reste introuvable', async () => {
    await as(token).get(`/api/v1/programs/${programId}/calendar?week=9`).expect(400);
    await as(token).get(`/api/v1/programs/${programId}/calendar?week=0`).expect(400);
    await as(otherToken).get(`/api/v1/programs/${programId}/calendar`).expect(404);
  });

  it('refuse une date qui n’existe pas, plutôt que de la corriger en douce', async () => {
    // `new Date('2026-02-31')` rend le 3 mars sans se plaindre : une date
    // corrigée derrière le dos de la personne est pire qu'un refus.
    for (const startsOn of ['2026-02-31', '21/09/2026', '2026-9-1']) {
      await as(token)
        .put(`/api/v1/programs/${programId}`)
        .send({ name: 'Date absurde', weeksCount: 1, startsOn, days: [] })
        .expect(400);
    }
  });

  it('le PUT décrit l’état complet : une date absente est une date retirée', async () => {
    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Sans calendrier', weeksCount: 1, days: [] })
      .expect(200);

    const detail = data<ProgramDetail>(
      (await as(token).get(`/api/v1/programs/${programId}`).expect(200)).body,
    );
    expect(detail.startsOn).toBeNull();
    await as(token).get(`/api/v1/programs/${programId}/calendar`).expect(400);
  });
});

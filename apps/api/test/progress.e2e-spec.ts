process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type BodyMetric,
  type ExerciseProgression,
  type LifetimeStats,
  type PersonalRecord,
  type ProgressOverview,
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
import { ensureExerciseFixture } from './support/exercise-fixture';

/**
 * Progression : records recalculés à la clôture, statistiques par période,
 * mesures corporelles idempotentes. Toutes les vues sont privées.
 */
describe('Progression (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let otherAccessToken: string;
  let exerciseId: string;
  let exerciseName: string;
  const userEmail = `e2e-progression-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-progression-autre-${randomUUID()}@carlys.test`;

  const now = Date.now();
  const at = (minutesAgo: number): string => new Date(now - minutesAgo * 60_000).toISOString();

  const sessionA = randomUUID();
  const sessionB = randomUUID();
  const sessionC = randomUUID();
  const metricId = randomUUID();
  const oldMetricId = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = (email: string) =>
      request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
        .expect(201);

    accessToken = data<AuthResult>((await register(userEmail)).body).tokens.accessToken;
    otherAccessToken = data<AuthResult>((await register(otherEmail)).body).tokens.accessToken;

    // Fixture dédiée : la suite ne dépend jamais du seed (base CI vierge).
    const exercise = await ensureExerciseFixture(prisma, 'e2e-progress-exercice');
    exerciseId = exercise.id;
    exerciseName = exercise.name;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: { in: [userEmail, otherEmail] } } });
    await prisma.exercise.deleteMany({
      where: { slug: { in: ['e2e-progress-exercice', 'e2e-progress-course'] } },
    });
    await prisma.$disconnect();
    await app.close();
  });

  const authed = (token: string) => ({
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
  });

  const createSession = async (id: string, startedMinutesAgo: number): Promise<void> => {
    await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send({ id, startedAt: at(startedMinutesAgo) })
      .expect(201);
  };

  const addSet = async (
    sessionId: string,
    position: number,
    reps: number,
    weightKg: number,
    completedMinutesAgo: number,
  ): Promise<void> => {
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseId,
        position,
        reps,
        weightKg,
        completedAt: at(completedMinutesAgo),
      })
      .expect(201);
  };

  it('crée les records à la clôture d’une première séance', async () => {
    await createSession(sessionA, 180);
    await addSet(sessionA, 0, 8, 60, 170); // volume 480
    await addSet(sessionA, 1, 12, 30, 160); // volume 360
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionA}/complete`)
      .send({ endedAt: at(120) }) // durée 3 600 s
      .expect(200);

    const records = data<PersonalRecord[]>(
      (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    const byType = new Map(records.map((record) => [record.recordType, record]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(60);
    expect(byType.get('MAX_REPS')?.value).toBe(12);
    expect(byType.get('MAX_SET_VOLUME')?.value).toBe(480);
    expect(byType.get('MAX_WEIGHT')?.exerciseName).toBe(exerciseName);
  });

  it('ne remplace un record que s’il est battu', async () => {
    await createSession(sessionB, 90);
    await addSet(sessionB, 0, 10, 70, 80); // bat MAX_WEIGHT (70) et MAX_SET_VOLUME (700), pas MAX_REPS
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionB}/complete`)
      .send({ endedAt: at(60) }) // durée 1 800 s
      .expect(200);

    const records = data<PersonalRecord[]>(
      (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    const byType = new Map(records.map((record) => [record.recordType, record]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(70);
    expect(byType.get('MAX_SET_VOLUME')?.value).toBe(700);
    expect(byType.get('MAX_REPS')?.value).toBe(12); // inchangé
  });

  it('une séance abandonnée ne touche pas aux records', async () => {
    await createSession(sessionC, 50);
    await addSet(sessionC, 0, 20, 100, 45);
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionC}/abandon`)
      .send({})
      .expect(200);

    const records = data<PersonalRecord[]>(
      (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    const byType = new Map(records.map((record) => [record.recordType, record]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(70);
  });

  it('agrège la période : totaux et volume par intervalle', async () => {
    const overview = data<ProgressOverview>(
      (await authed(accessToken).get('/api/v1/progress/overview?period=week').expect(200)).body,
    );

    expect(overview.period).toBe('week');
    expect(overview.sessionsCount).toBe(2); // la séance abandonnée est exclue
    expect(overview.setsCount).toBe(3);
    expect(overview.totalVolumeKg).toBe(480 + 360 + 700);
    expect(overview.totalDurationSeconds).toBe(3_600 + 1_800);
    expect(overview.points.length).toBeGreaterThan(0);
    const bucketVolume = overview.points.reduce((sum, point) => sum + point.volumeKg, 0);
    expect(bucketVolume).toBe(overview.totalVolumeKg);

    // Les trois périodes répondent avec la même enveloppe.
    for (const period of ['month', 'year'] as const) {
      const other = data<ProgressOverview>(
        (await authed(accessToken).get(`/api/v1/progress/overview?period=${period}`).expect(200))
          .body,
      );
      expect(other.period).toBe(period);
      expect(other.sessionsCount).toBe(2);
    }
    await authed(accessToken).get('/api/v1/progress/overview?period=decade').expect(400);
  });

  it('compte la VIE ENTIÈRE, sans borne ni plafond', async () => {
    // Le mobile dérivait ces compteurs de son historique LOCAL, plafonné à
    // 60 séances au rapatriement : sur un compte plus fourni, un téléphone
    // neuf ne re-méritait pas `discipline-150` et la récompense
    // disparaissait. Cette lecture-ci ne connaît pas de plafond.
    const lifetime = data<LifetimeStats>(
      (await authed(accessToken).get('/api/v1/progress/lifetime').expect(200)).body,
    );

    // Deux séances TERMINÉES ; la troisième a été abandonnée et ne compte
    // pas — la même règle que partout ailleurs dans la progression.
    expect(lifetime.completedSessions).toBe(2);
    expect(lifetime.weeks.reduce((total, week) => total + week.sessions, 0)).toBe(2);
    // Des FAITS, pas une règle : aucune « meilleure série » n'est servie,
    // c'est le moteur de récompenses du mobile qui la décide, et lui seul.
    for (const week of lifetime.weeks) {
      expect(week.mondayOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      // `date_trunc('week', …)` rend un LUNDI, dans le fuseau de la personne.
      expect(new Date(`${week.mondayOn}T12:00:00Z`).getUTCDay()).toBe(1);
    }
  });

  it('la vie entière d’autrui reste invisible', async () => {
    const lifetime = data<LifetimeStats>(
      (await authed(otherAccessToken).get('/api/v1/progress/lifetime').expect(200)).body,
    );
    expect(lifetime.completedSessions).toBe(0);
    expect(lifetime.weeks).toEqual([]);
  });

  it('trace la progression sur un exercice du catalogue', async () => {
    const progression = data<ExerciseProgression>(
      (await authed(accessToken).get(`/api/v1/progress/exercises/${exerciseId}`).expect(200)).body,
    );

    expect(progression.exerciseName).toBe(exerciseName);
    expect(progression.points).toHaveLength(2); // séances terminées uniquement
    expect(progression.points[0]?.maxWeightKg).toBe(60);
    expect(progression.points[1]?.maxWeightKg).toBe(70);
    // Une séance de FONTE n'a ni distance ni chrono, et zéro est exact ici :
    // c'est ce qui permet au client de choisir la courbe à tracer.
    expect(progression.points[0]?.distanceMeters).toBe(0);
    expect(progression.points[0]?.durationSeconds).toBe(0);
    expect(progression.records.find((record) => record.recordType === 'MAX_WEIGHT')?.value).toBe(
      70,
    );

    await authed(accessToken).get(`/api/v1/progress/exercises/${randomUUID()}`).expect(404);
  });

  it('trace aussi le CARDIO : distance et chrono, SOMMÉS par séance', async () => {
    // Un exercice à part : la course n'a pas de charge, et c'est exactement
    // le cas que la courbe de kilos rendait comme « pas encore de courbe ».
    const course = await ensureExerciseFixture(prisma, 'e2e-progress-course');
    const sessionD = randomUUID();
    await createSession(sessionD, 120);

    // Trois fractionnés de 400 m : la distance s'ADDITIONNE d'une série à
    // l'autre, là où une charge se maximise. C'est la différence qui a
    // décidé du `SUM` plutôt que du `MAX`.
    for (const position of [0, 1, 2]) {
      await authed(accessToken)
        .post(`/api/v1/workout-sessions/${sessionD}/sets`)
        .send({
          id: randomUUID(),
          exerciseId: course.id,
          position,
          distanceMeters: 400,
          durationSeconds: 90,
          completedAt: at(110 - position),
        })
        .expect(201);
    }
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionD}/complete`)
      .send({})
      .expect(200);

    const progression = data<ExerciseProgression>(
      (await authed(accessToken).get(`/api/v1/progress/exercises/${course.id}`).expect(200)).body,
    );

    expect(progression.points).toHaveLength(1);
    expect(progression.points[0]?.distanceMeters).toBe(1_200);
    expect(progression.points[0]?.durationSeconds).toBe(270);
    // Et aucune charge : le tiret de l'écran ne ment pas, il n'y en a pas.
    expect(progression.points[0]?.maxWeightKg).toBeNull();
    expect(progression.points[0]?.volumeKg).toBe(0);
  });

  it('la progression d’autrui reste invisible', async () => {
    const records = data<PersonalRecord[]>(
      (await authed(otherAccessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    expect(records).toHaveLength(0);

    const overview = data<ProgressOverview>(
      (await authed(otherAccessToken).get('/api/v1/progress/overview').expect(200)).body,
    );
    expect(overview.sessionsCount).toBe(0);

    await request(app.getHttpServer()).get('/api/v1/progress/overview').expect(401);
  });

  it('enregistre une mesure corporelle et REJOUE la création sans doublon', async () => {
    const payload = {
      id: metricId,
      metricType: 'WEIGHT_KG',
      value: 82.5,
      measuredAt: at(60),
    };

    const first = await authed(accessToken).post('/api/v1/body-metrics').send(payload).expect(201);
    expect(data<BodyMetric>(first.body).value).toBe(82.5);

    await authed(accessToken).post('/api/v1/body-metrics').send(payload).expect(201);
    const count = await prisma.bodyMetric.count({ where: { id: metricId } });
    expect(count).toBe(1);

    // Le même id revendiqué par un autre utilisateur est un conflit.
    await authed(otherAccessToken).post('/api/v1/body-metrics').send(payload).expect(409);

    // Valeur hors bornes refusée.
    await authed(accessToken)
      .post('/api/v1/body-metrics')
      .send({ ...payload, id: randomUUID(), value: 5_000 })
      .expect(400);
  });

  it('liste les mesures du plus ancien au plus récent, par type', async () => {
    await authed(accessToken)
      .post('/api/v1/body-metrics')
      .send({
        id: oldMetricId,
        metricType: 'WEIGHT_KG',
        value: 84,
        measuredAt: at(60 * 24 * 10), // il y a 10 jours
      })
      .expect(201);

    const metrics = data<BodyMetric[]>(
      (await authed(accessToken).get('/api/v1/body-metrics').expect(200)).body,
    );
    expect(metrics.map((metric) => metric.id)).toEqual([oldMetricId, metricId]);

    const fat = data<BodyMetric[]>(
      (
        await authed(accessToken)
          .get('/api/v1/body-metrics?metricType=BODY_FAT_PERCENT')
          .expect(200)
      ).body,
    );
    expect(fat).toHaveLength(0);

    // Invisible pour un autre utilisateur.
    const others = data<BodyMetric[]>(
      (await authed(otherAccessToken).get('/api/v1/body-metrics').expect(200)).body,
    );
    expect(others).toHaveLength(0);
  });

  it('supprime une mesure (suppression logique rejouable)', async () => {
    await authed(accessToken).delete(`/api/v1/body-metrics/${oldMetricId}`).expect(204);
    await authed(accessToken).delete(`/api/v1/body-metrics/${oldMetricId}`).expect(204);

    const metrics = data<BodyMetric[]>(
      (await authed(accessToken).get('/api/v1/body-metrics').expect(200)).body,
    );
    expect(metrics.map((metric) => metric.id)).toEqual([metricId]);

    // La mesure d'autrui reste invisible, même à la suppression.
    await authed(otherAccessToken).delete(`/api/v1/body-metrics/${metricId}`).expect(404);
  });

  it('corrige une mesure : valeur, date, et les refus', async () => {
    const id = randomUUID();
    await authed(accessToken)
      .post('/api/v1/body-metrics')
      .send({ id, metricType: 'WEIGHT_KG', value: 90, measuredAt: at(30) })
      .expect(201);

    const corrigee = data<BodyMetric>(
      (
        await authed(accessToken)
          .patch(`/api/v1/body-metrics/${id}`)
          .send({ value: 88.4 })
          .expect(200)
      ).body,
    );
    expect(corrigee.value).toBe(88.4);

    // La date seule se corrige aussi — c'est elle qui décide, plus loin,
    // quelle mesure fait foi pour le rapport métabolique.
    const veille = at(60 * 24);
    const redatee = data<BodyMetric>(
      (
        await authed(accessToken)
          .patch(`/api/v1/body-metrics/${id}`)
          .send({ measuredAt: veille })
          .expect(200)
      ).body,
    );
    expect(new Date(redatee.measuredAt).toISOString()).toBe(new Date(veille).toISOString());
    expect(redatee.value).toBe(88.4); // la valeur n'a pas bougé

    // Un corps vide n'est pas une correction.
    await authed(accessToken).patch(`/api/v1/body-metrics/${id}`).send({}).expect(400);
    // Hors bornes, comme à la création.
    await authed(accessToken)
      .patch(`/api/v1/body-metrics/${id}`)
      .send({ value: 5_000 })
      .expect(400);
    // Le type ne se corrige pas : `forbidNonWhitelisted` refuse le champ.
    await authed(accessToken)
      .patch(`/api/v1/body-metrics/${id}`)
      .send({ metricType: 'BODY_FAT_PERCENT' })
      .expect(400);
    // La mesure d'autrui est introuvable, jamais interdite.
    await authed(otherAccessToken)
      .patch(`/api/v1/body-metrics/${id}`)
      .send({ value: 70 })
      .expect(404);

    // Une mesure supprimée ne se corrige plus : le client croirait sa
    // correction enregistrée alors que la ligne ne compte plus.
    await authed(accessToken).delete(`/api/v1/body-metrics/${id}`).expect(204);
    await authed(accessToken).patch(`/api/v1/body-metrics/${id}`).send({ value: 70 }).expect(404);
  });

  /**
   * CE QUE CE TEST PROTÈGE, et que rien ne disait : une mesure de poids
   * n'appartient pas au seul domaine « progression ». Le rapport métabolique
   * (métabolisme de base, dépense, cible calorique, protéines, eau, IMC) est
   * calculé à partir du DERNIER poids non supprimé, choisi par `measuredAt`
   * décroissant. Corriger un poids change donc les objectifs nutritionnels de
   * la personne — et corriger une DATE suffit à changer QUELLE mesure fait
   * foi, sans qu'aucune valeur ne bouge. C'est le comportement voulu ; sans
   * ce test, rien n'empêcherait de le casser sans s'en apercevoir, le
   * symptôme n'apparaissant que dans un autre module.
   */
  it('corriger un poids déplace le rapport métabolique', async () => {
    await authed(accessToken)
      .patch('/api/v1/users/me')
      .send({
        sex: 'MALE',
        birthDate: '1996-01-15T00:00:00.000Z',
        heightCm: 180,
        activityLevel: 'MODERATE',
        nutritionGoal: 'MAINTAIN',
      })
      .expect(200);

    const recent = randomUUID();
    await authed(accessToken)
      .post('/api/v1/body-metrics')
      .send({ id: recent, metricType: 'WEIGHT_KG', value: 80, measuredAt: at(1) })
      .expect(201);

    const avant = data<{ profile: { weightKg: number | null } }>(
      (await authed(accessToken).get('/api/v1/nutrition/metabolism').expect(200)).body,
    );
    expect(avant.profile.weightKg).toBe(80);

    await authed(accessToken)
      .patch(`/api/v1/body-metrics/${recent}`)
      .send({ value: 74 })
      .expect(200);

    const apres = data<{ profile: { weightKg: number | null } }>(
      (await authed(accessToken).get('/api/v1/nutrition/metabolism').expect(200)).body,
    );
    expect(apres.profile.weightKg).toBe(74);
  });

  /**
   * Le record faux et définitif. Placé en FIN de fichier à dessein : il
   * ajoute une séance, et les tests d'agrégation plus haut comptent les
   * séances et les séries de la période.
   */
  describe('une charge mal saisie ne reste pas un record', () => {
    const sessionD = randomUUID();
    const setFautif = randomUUID();

    const maxWeight = async (): Promise<number | undefined> => {
      const records = data<PersonalRecord[]>(
        (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
      );
      return records.find((record) => record.recordType === 'MAX_WEIGHT')?.value;
    };

    it('200 kg au lieu de 20 : corrigé, le record REDESCEND à la vraie valeur', async () => {
      await createSession(sessionD, 40);
      await authed(accessToken)
        .post(`/api/v1/workout-sessions/${sessionD}/sets`)
        .send({
          id: setFautif,
          exerciseId,
          position: 0,
          reps: 5,
          weightKg: 200, // le zéro de trop
          completedAt: at(35),
        })
        .expect(201);
      await authed(accessToken)
        .post(`/api/v1/workout-sessions/${sessionD}/complete`)
        .send({ endedAt: at(30) })
        .expect(200);

      expect(await maxWeight()).toBe(200);

      await authed(accessToken)
        .patch(`/api/v1/workout-sets/${setFautif}`)
        .send({ weightKg: 20 })
        .expect(200);

      // 70 kg est le vrai meilleur, posé par la séance B bien plus haut :
      // c'est l'HISTORIQUE qui le rend, pas un maximum resté en mémoire.
      expect(await maxWeight()).toBe(70);
    });

    it('supprimer la série fautive donne le même résultat', async () => {
      const autre = randomUUID();
      await createSession(autre, 25);
      const setSupprime = randomUUID();
      await authed(accessToken)
        .post(`/api/v1/workout-sessions/${autre}/sets`)
        .send({
          id: setSupprime,
          exerciseId,
          position: 0,
          reps: 5,
          weightKg: 300,
          completedAt: at(22),
        })
        .expect(201);
      await authed(accessToken)
        .post(`/api/v1/workout-sessions/${autre}/complete`)
        .send({ endedAt: at(20) })
        .expect(200);

      expect(await maxWeight()).toBe(300);

      await authed(accessToken).delete(`/api/v1/workout-sets/${setSupprime}`).expect(204);

      expect(await maxWeight()).toBe(70);
    });
  });
});

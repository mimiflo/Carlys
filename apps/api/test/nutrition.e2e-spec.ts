process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type MealEntry,
  type AuthResult,
  type MetabolismReport,
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
 * Nutrition : profil métabolique complété pas à pas, rapport calculé côté
 * serveur uniquement, poids tiré de la dernière mesure corporelle.
 */
describe('Nutrition (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  const userEmail = `e2e-nutrition-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  const authed = () => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${accessToken}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${accessToken}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${accessToken}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${accessToken}`),
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: userEmail, password: 'MotDePasseSolide42', displayName: 'E2E' })
      .expect(201);
    accessToken = data<AuthResult>(response.body).tokens.accessToken;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: userEmail } });
    await prisma.$disconnect();
    await app.close();
  });

  it('nouveau compte : rapport incomplet, champs manquants LISTÉS', async () => {
    const report = data<MetabolismReport>(
      (await authed().get('/api/v1/nutrition/metabolism').expect(200)).body,
    );

    expect(report.metabolism).toBeNull();
    expect(report.missing).toEqual(
      expect.arrayContaining(['sex', 'birthDate', 'heightCm', 'activityLevel', 'weightKg']),
    );
    await request(app.getHttpServer()).get('/api/v1/nutrition/metabolism').expect(401);
  });

  it('refuse une date de naissance future ou une taille aberrante', async () => {
    await authed()
      .patch('/api/v1/users/me')
      .send({ birthDate: '2030-01-01T00:00:00.000Z' })
      .expect(400);
    await authed().patch('/api/v1/users/me').send({ heightCm: 400 }).expect(400);
    await authed().patch('/api/v1/users/me').send({ sex: 'AUTRE' }).expect(400);
  });

  it('profil complété + poids mesuré → rapport calculé (valeurs Mifflin-St Jeor)', async () => {
    await authed()
      .patch('/api/v1/users/me')
      .send({
        sex: 'MALE',
        birthDate: '1996-01-15T00:00:00.000Z', // 30 ans au moment du test
        heightCm: 180,
        activityLevel: 'MODERATE',
        nutritionGoal: 'MAINTAIN',
      })
      .expect(200);

    await authed()
      .post('/api/v1/body-metrics')
      .send({
        id: randomUUID(),
        metricType: 'WEIGHT_KG',
        value: 80,
        measuredAt: new Date().toISOString(),
      })
      .expect(201);

    const report = data<MetabolismReport>(
      (await authed().get('/api/v1/nutrition/metabolism').expect(200)).body,
    );

    expect(report.missing).toEqual([]);
    expect(report.profile.weightKg).toBe(80);
    expect(report.profile.ageYears).toBe(30);
    // BMR : 10·80 + 6,25·180 − 5·30 + 5 = 1780 ; TDEE : ×1,55.
    expect(report.metabolism?.bmrKcal).toBe(1780);
    expect(report.metabolism?.tdeeKcal).toBe(2759);
    expect(report.metabolism?.targetKcal).toBe(2759);
    expect(report.metabolism?.proteinG).toBe(128);
    expect(report.metabolism?.bmiCategory).toBe('NORMAL');
    expect(report.metabolism?.waterMl).toBe(2800);
  });

  it('le rapport suit la DERNIÈRE mesure de poids', async () => {
    await authed()
      .post('/api/v1/body-metrics')
      .send({
        id: randomUUID(),
        metricType: 'WEIGHT_KG',
        value: 76,
        measuredAt: new Date().toISOString(),
      })
      .expect(201);

    const report = data<MetabolismReport>(
      (await authed().get('/api/v1/nutrition/metabolism').expect(200)).body,
    );

    expect(report.profile.weightKg).toBe(76);
    expect(report.metabolism?.waterMl).toBe(Math.round(35 * 76));
  });

  it('journal alimentaire : ajout idempotent, journée bornée par le client, retrait', async () => {
    const mealId = randomUUID();
    const noon = new Date();
    const dayStart = new Date(noon.getTime() - 12 * 3_600_000);
    const dayEnd = new Date(noon.getTime() + 12 * 3_600_000);
    const payload = {
      id: mealId,
      name: 'Poulet riz',
      kcal: 650,
      // Les trois macros sont INDÉPENDANTES : ici les lipides ne sont pas
      // connus, et l'entrée doit passer quand même.
      proteinG: 45,
      carbsG: 80,
      eatenAt: noon.toISOString(),
    };

    // Créer, puis REJOUER : une seule entrée.
    await authed().post('/api/v1/nutrition/meals').send(payload).expect(201);
    await authed().post('/api/v1/nutrition/meals').send(payload).expect(201);

    const window = `from=${dayStart.toISOString()}&to=${dayEnd.toISOString()}`;
    let meals = data<MealEntry[]>(
      (await authed().get(`/api/v1/nutrition/meals?${window}`).expect(200)).body,
    );
    expect(meals).toHaveLength(1);
    expect(meals[0]?.kcal).toBe(650);
    expect(meals[0]?.carbsG).toBe(80);
    // `null`, jamais 0 : l'absence d'une macro se distingue d'un zéro, sinon
    // l'écran afficherait « 0 g de lipides » pour « on ne sait pas ».
    expect(meals[0]?.fatG).toBeNull();

    // Hors fenêtre : la même liste, interrogée sur la veille, est vide.
    const previousWindow = `from=${new Date(dayStart.getTime() - 24 * 3_600_000).toISOString()}&to=${dayStart.toISOString()}`;
    const yesterday = data<MealEntry[]>(
      (await authed().get(`/api/v1/nutrition/meals?${previousWindow}`).expect(200)).body,
    );
    expect(yesterday).toHaveLength(0);

    // Retrait doux, idempotent.
    await authed().delete(`/api/v1/nutrition/meals/${mealId}`).expect(204);
    await authed().delete(`/api/v1/nutrition/meals/${mealId}`).expect(204);
    meals = data<MealEntry[]>(
      (await authed().get(`/api/v1/nutrition/meals?${window}`).expect(200)).body,
    );
    expect(meals).toHaveLength(0);
  });

  it('refuse un repas sans calories positives', async () => {
    await authed()
      .post('/api/v1/nutrition/meals')
      .send({ id: randomUUID(), name: 'Rien', kcal: 0, eatenAt: new Date().toISOString() })
      .expect(400);
  });

  it('journalise une quantité — descriptive, jamais multiplicatrice', async () => {
    const mealId = randomUUID();
    const eatenAt = new Date();
    await authed()
      .post('/api/v1/nutrition/meals')
      .send({
        id: mealId,
        name: 'Riz basmati',
        kcal: 350,
        quantity: 250.5,
        quantityUnit: 'GRAM',
        eatenAt: eatenAt.toISOString(),
      })
      .expect(201);

    const window = `from=${new Date(eatenAt.getTime() - 3_600_000).toISOString()}&to=${new Date(eatenAt.getTime() + 3_600_000).toISOString()}`;
    const meals = data<MealEntry[]>(
      (await authed().get(`/api/v1/nutrition/meals?${window}`).expect(200)).body,
    );
    const stored = meals.find((meal) => meal.id === mealId);
    // Un NOMBRE, pas la chaîne « 250.5 » : le `Decimal` de Prisma se
    // sérialise en chaîne si personne ne le convertit, et le contrat la
    // refuserait.
    expect(stored?.quantity).toBe(250.5);
    expect(stored?.quantityUnit).toBe('GRAM');
    // Les calories restent le TOTAL mangé : elles ne sont pas multipliées
    // par 250,5 au passage.
    expect(stored?.kcal).toBe(350);
  });

  it('refuse une quantité orpheline de son unité, dans les deux sens', async () => {
    for (const orpheline of [{ quantity: 250 }, { quantityUnit: 'GRAM' }]) {
      await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Moitié de phrase',
          kcal: 350,
          ...orpheline,
          eatenAt: new Date().toISOString(),
        })
        .expect(400);
    }
  });

  it('refuse un repas mangé dans le futur, à la création comme à la correction', async () => {
    const mealId = randomUUID();
    const nextWeek = new Date(Date.now() + 7 * 24 * 3_600_000).toISOString();
    // Hors du jour courant pour toujours : le total « consommé » de l'accueil
    // ne le verrait plus, et la personne chercherait un repas pourtant bien
    // enregistré.
    await authed()
      .post('/api/v1/nutrition/meals')
      .send({ id: mealId, name: 'Demain', kcal: 500, eatenAt: nextWeek })
      .expect(400);

    await authed()
      .post('/api/v1/nutrition/meals')
      .send({ id: mealId, name: 'Aujourd’hui', kcal: 500, eatenAt: new Date().toISOString() })
      .expect(201);

    // La correction porte la MÊME borne : sans elle, elle rouvrirait la porte
    // que la création vient de fermer.
    await authed()
      .patch(`/api/v1/nutrition/meals/${mealId}`)
      .send({ eatenAt: nextWeek })
      .expect(400);
  });

  it('corrige un repas sans effacer ce qu’on ne lui redonne pas', async () => {
    const mealId = randomUUID();
    const eatenAt = new Date();
    await authed()
      .post('/api/v1/nutrition/meals')
      .send({
        id: mealId,
        name: 'Poulet riz',
        kcal: 650,
        proteinG: 45,
        carbsG: 80,
        quantity: 1,
        quantityUnit: 'PORTION',
        eatenAt: eatenAt.toISOString(),
      })
      .expect(201);

    const corrected = data<MealEntry>(
      (await authed().patch(`/api/v1/nutrition/meals/${mealId}`).send({ kcal: 700 }).expect(200))
        .body,
    );
    expect(corrected.kcal).toBe(700);
    // Ni les macros ni la quantité n'ont bougé : elles n'étaient pas dans le
    // corps de la requête.
    expect(corrected.proteinG).toBe(45);
    expect(corrected.quantity).toBe(1);

    // `null` EFFACE, lui : on ne sait plus combien de protéines.
    const erased = data<MealEntry>(
      (
        await authed()
          .patch(`/api/v1/nutrition/meals/${mealId}`)
          .send({ proteinG: null })
          .expect(200)
      ).body,
    );
    expect(erased.proteinG).toBeNull();
    expect(erased.carbsG).toBe(80);

    // Un corps vide n'est pas une correction ; un `null` sur un champ qui ne
    // peut pas l'être non plus.
    await authed().patch(`/api/v1/nutrition/meals/${mealId}`).send({}).expect(400);
    await authed().patch(`/api/v1/nutrition/meals/${mealId}`).send({ kcal: null }).expect(400);
    // Défaire la moitié d'une paire laisserait « 1 » sans unité.
    await authed()
      .patch(`/api/v1/nutrition/meals/${mealId}`)
      .send({ quantityUnit: null })
      .expect(400);

    // Un repas supprimé n'est plus corrigible, et un inconnu répond pareil.
    await authed().delete(`/api/v1/nutrition/meals/${mealId}`).expect(204);
    await authed().patch(`/api/v1/nutrition/meals/${mealId}`).send({ kcal: 700 }).expect(404);
    await authed().patch(`/api/v1/nutrition/meals/${randomUUID()}`).send({ kcal: 700 }).expect(404);
  });

  it('refuse une macro hors bornes, sans la tronquer en silence', async () => {
    for (const macro of ['proteinG', 'carbsG', 'fatG']) {
      await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Absurde',
          kcal: 650,
          [macro]: 2_000,
          eatenAt: new Date().toISOString(),
        })
        .expect(400);
    }
  });
});

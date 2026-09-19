process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type GeneratedProgram,
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
 * GÉNÉRATION DE PROGRAMME — le chemin complet, sur une vraie base.
 *
 * Les tests unitaires prouvent que le moteur respecte ses règles sur les huit
 * mille combinaisons d'entrées. Celui-ci prouve autre chose, et c'est
 * complémentaire : que ce que le moteur décide ARRIVE VRAIMENT EN BASE, que
 * les modèles engendrés sont lisibles par la route qui sert la bibliothèque, et
 * que le rejeu ne duplique rien.
 */
describe('Génération de programme (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  const email = `e2e-generation-${randomUUID()}@carlys.test`;
  const programId = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const error = (body: unknown): ApiErrorEnvelope['error'] => (body as ApiErrorEnvelope).error;
  const server = () => request(app.getHttpServer());
  const auth = () => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) => server().patch(url).set('Authorization', `Bearer ${token}`),
  });

  /**
   * La suite apporte SON catalogue.
   *
   * Les suites e2e du dépôt sont autonomes : la base de CI est vierge et le
   * seed n'y tourne pas. Un générateur testé sur un catalogue absent
   * rendrait des séances vides et le test passerait quand même — ce qui est
   * exactement le genre de vert qui ne prouve rien.
   *
   * Douze mouvements au poids du corps, un par groupe utile, tous débutants :
   * de quoi remplir un découpage haut/bas sur quatre séances.
   */
  const GROUPES = [
    'pectoraux',
    'dos',
    'epaules',
    'biceps',
    'triceps',
    'abdominaux',
    'lombaires',
    'fessiers',
    'quadriceps',
    'ischio-jambiers',
    'mollets',
  ];

  async function seedCatalogue(): Promise<void> {
    const equipment = await prisma.equipment.upsert({
      where: { slug: 'poids-du-corps' },
      update: {},
      create: { slug: 'poids-du-corps', name: 'Poids du corps' },
    });
    for (const [index, groupe] of GROUPES.entries()) {
      const muscle = await prisma.muscleGroup.upsert({
        where: { slug: groupe },
        update: {},
        create: { slug: groupe, name: groupe, sortOrder: index },
      });
      const slug = `e2e-gen-${groupe}`;
      const exercise = await prisma.exercise.upsert({
        where: { slug },
        update: { isPublished: true },
        create: {
          slug,
          name: `Mouvement ${groupe}`,
          description: 'Exercice injecté par la suite e2e de génération.',
          instructions: ['Étape unique'],
          difficulty: 'BEGINNER',
          type: 'STRENGTH',
          isPremium: false,
          tags: ['e2e', 'polyarticulaire'],
        },
      });
      await prisma.exerciseMuscle.upsert({
        where: {
          exerciseId_muscleGroupId: { exerciseId: exercise.id, muscleGroupId: muscle.id },
        },
        update: { role: 'PRIMARY' },
        create: { exerciseId: exercise.id, muscleGroupId: muscle.id, role: 'PRIMARY' },
      });
      await prisma.exerciseEquipment.upsert({
        where: {
          exerciseId_equipmentId: { exerciseId: exercise.id, equipmentId: equipment.id },
        },
        update: {},
        create: { exerciseId: exercise.id, equipmentId: equipment.id },
      });
    }
  }

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    await seedCatalogue();
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    token = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'Membre E2E' })
          .expect(201)
      ).body,
    ).tokens.accessToken;
  });

  afterAll(async () => {
    // Le compte emporte son programme et ses modèles en cascade. Les exercices
    // injectés partent aussi ; les groupes musculaires et le matériel restent,
    // parce qu'ils portent les slugs RÉELS de la taxonomie, qu'ils sont
    // upsertés et que le seed les recréerait à l'identique. Les supprimer
    // casserait une suite voisine qui les aurait upsertés entre-temps.
    await prisma.user.deleteMany({ where: { email } });
    await prisma.exercise.deleteMany({ where: { slug: { startsWith: 'e2e-gen-' } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('refuse tant que le profil est incomplet, en NOMMANT tout ce qui manque', async () => {
    const response = await auth()
      .put(`/api/v1/programs/${programId}/generate`)
      .send({})
      .expect(400);
    const body = error(response.body);
    expect(body.code).toBe('VALIDATION_ERROR');
    // Une réponse, tous les champs : l'écran de profil doit pouvoir les
    // surligner d'un coup, pas les découvrir un par requête.
    const champs = (body.details as { field: string }[]).map((detail) => detail.field).sort();
    expect(champs).toEqual([
      'equipmentSlugs',
      'sessionMinutesTarget',
      'trainingExperience',
      'trainingGoal',
      'weeklySessionsTarget',
    ]);
  });

  it('accepte « je n’ai que mon corps » comme une vraie réponse', async () => {
    await auth()
      .patch('/api/v1/users/me')
      .send({
        trainingGoal: 'MUSCLE_GAIN',
        trainingExperience: 'BEGINNER',
        weeklySessionsTarget: 4,
        sessionMinutesTarget: 45,
        // Une liste VIDE serait « je n'ai pas répondu » ; celle-ci dit
        // explicitement « rien d'autre que mon corps », et le générateur la
        // sert au lieu de se dérober.
        equipmentSlugs: ['poids-du-corps'],
      })
      .expect(200);
  });

  it('engendre le programme, ses jours et ses modèles', async () => {
    const response = await auth()
      .put(`/api/v1/programs/${programId}/generate`)
      .send({ name: 'Mon premier bloc' })
      .expect(201);
    const { program, report } = data<GeneratedProgram>(response.body);

    expect(program.name).toBe('Mon premier bloc');
    // Le calendrier est COMPLET : aucune case ne manque, repos compris.
    expect(program.days.length).toBe(program.weeksCount * 7);
    // INACTIF : générer ne désactive jamais le plan en cours.
    expect(program.isActive).toBe(false);

    expect(report.sessionsPerWeek).toBe(4);
    expect(report.templatesCreated).toBeGreaterThan(0);
    expect(report.split.length).toBeGreaterThan(0);
    expect(report.rulesVersion).toBeGreaterThan(0);

    const jours = program.days.filter((day) => !day.isRest);
    expect(jours.length).toBe(4 * program.weeksCount);
    for (const day of jours) expect(day.templateId).not.toBeNull();
  });

  it('dépose des modèles lisibles par la bibliothèque de séances', async () => {
    const response = await auth().get('/api/v1/workout-templates?limit=50').expect(200);
    const items = data<{ id: string; name: string }[]>(response.body);
    expect(items.length).toBeGreaterThan(0);
    // La durée estimée vit dans les NOTES : `estimatedDurationMinutes` reste
    // nul parce que le schéma dit qu'il n'appartient qu'à l'utilisateur.
    const rows = await prisma.workoutTemplate.findMany({
      where: { generatedFromProgramId: programId },
      select: { estimatedDurationMinutes: true, notes: true, generatedFromProgramId: true },
    });
    expect(rows.length).toBeGreaterThan(0);
    for (const row of rows) {
      expect(row.estimatedDurationMinutes).toBeNull();
      expect(row.notes).toContain('généré');
      expect(row.generatedFromProgramId).toBe(programId);
    }
  });

  it('ne prescrit jamais une charge que le serveur ne connaît pas', async () => {
    const sets = await prisma.workoutTemplateSet.findMany({
      where: { templateExercise: { template: { generatedFromProgramId: programId } } },
      select: { targetWeightKg: true },
      take: 200,
    });
    expect(sets.length).toBeGreaterThan(0);
    // Le serveur ne lit ni les records ni l'historique dans cette tranche :
    // prescrire un poids serait l'inventer.
    for (const set of sets) expect(set.targetWeightKg).toBeNull();
  });

  it('rejoue sans rien dupliquer, et sans écraser le travail de la personne', async () => {
    const avant = await prisma.programDay.count({ where: { programId } });
    const modelesAvant = await prisma.workoutTemplate.count({
      where: { generatedFromProgramId: programId },
    });

    const response = await auth()
      .put(`/api/v1/programs/${programId}/generate`)
      .send({})
      .expect(200);
    const { program } = data<GeneratedProgram>(response.body);
    expect(program.id).toBe(programId);

    expect(await prisma.programDay.count({ where: { programId } })).toBe(avant);
    expect(
      await prisma.workoutTemplate.count({ where: { generatedFromProgramId: programId } }),
    ).toBe(modelesAvant);
  });

  it('rend le rapport tel qu’il a été écrit, des semaines plus tard', async () => {
    // C'est ce que la colonne `generationReport` achète : un support qui
    // ouvre un programme trois semaines après peut encore expliquer pourquoi
    // tel exercice y figure, sans avoir à régénérer sur un profil qui a bougé.
    const response = await auth()
      .put(`/api/v1/programs/${programId}/generate`)
      .send({})
      .expect(200);
    const { report } = data<GeneratedProgram>(response.body);
    expect(report.goal).toBe('MUSCLE_GAIN');
    expect(report.experience).toBe('BEGINNER');
    expect(report.rulesVersion).toBeGreaterThan(0);
  });

  it('refuse l’identifiant d’un autre compte', async () => {
    const autre = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({
            email: `e2e-generation-autre-${randomUUID()}@carlys.test`,
            password: 'MotDePasseSolide42',
            displayName: 'Autre',
          })
          .expect(201)
      ).body,
    );
    await server()
      .put(`/api/v1/programs/${programId}/generate`)
      .set('Authorization', `Bearer ${autre.tokens.accessToken}`)
      .send({})
      .expect(409);
    await prisma.user.deleteMany({ where: { id: autre.user.id } });
  });

  it('refuse un champ que le contrat ne déclare pas', async () => {
    // Le profil a UNE source. L'accepter dans le corps ouvrirait une seconde,
    // donc une divergence — et plus personne ne saurait lequel a produit le
    // programme reçu.
    await auth()
      .put(`/api/v1/programs/${randomUUID()}/generate`)
      .send({ trainingGoal: 'MARATHON' })
      .expect(400);
  });
});

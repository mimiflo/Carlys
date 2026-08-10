process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  ADMIN_PERMISSIONS,
  type AdminAuditLog,
  type AdminExerciseSummary,
  type AdminLoginResult,
  type AdminMe,
  type AdminOverview,
  type ApiSuccessEnvelope,
  type AuthResult,
  type EntitlementsResponse,
  type ManagedUserDetail,
  type ManagedUserSummary,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { ensureExerciseFixture } from './support/exercise-fixture';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Administration : comptes SÉPARÉS, RBAC par permission, audit systématique.
 * La suspension révoque les sessions ; les jetons admin et mobiles ne sont
 * jamais interchangeables.
 */
describe('Administration (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let superToken: string;
  let supportToken: string;
  let memberToken: string;
  let memberId: string;
  const superEmail = `e2e-admin-super-${randomUUID()}@carlys.test`;
  const supportEmail = `e2e-admin-support-${randomUUID()}@carlys.test`;
  const memberEmail = `e2e-admin-membre-${randomUUID()}@carlys.test`;
  const witnessEmail = `e2e-admin-temoin-${randomUUID()}@carlys.test`;
  let witnessToken: string;
  let freeExerciseSlug: string;
  let freeExerciseId: string;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  const server = () => request(app.getHttpServer());
  const asAdmin = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) => server().patch(url).set('Authorization', `Bearer ${token}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    // RBAC : mêmes upserts idempotents que le seed (suite autonome).
    for (const permission of ADMIN_PERMISSIONS) {
      const [resource, action] = permission.split(':') as [string, string];
      await prisma.adminPermission.upsert({
        where: { resource_action: { resource, action } },
        update: {},
        create: { resource, action },
      });
    }
    const permissions = await prisma.adminPermission.findMany();
    const roleOf = async (slug: string, name: string, keys: readonly string[]) => {
      const role = await prisma.adminRole.upsert({
        where: { slug },
        update: {},
        create: { slug, name },
      });
      await prisma.adminRolePermission.deleteMany({ where: { roleId: role.id } });
      await prisma.adminRolePermission.createMany({
        data: permissions
          .filter((permission) => keys.includes(`${permission.resource}:${permission.action}`))
          .map((permission) => ({ roleId: role.id, permissionId: permission.id })),
      });
      return role;
    };
    const superRole = await roleOf('superadmin', 'Super-administrateur', ADMIN_PERMISSIONS);
    const supportRole = await roleOf('support', 'Support', ['user:read', 'audit:read']);

    const passwordHash = await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id });
    for (const [email, role] of [
      [superEmail, superRole],
      [supportEmail, supportRole],
    ] as const) {
      const admin = await prisma.adminUser.create({
        data: { email, displayName: 'Admin E2E', passwordHash },
      });
      await prisma.adminUserRole.create({
        data: { adminUserId: admin.id, roleId: role.id },
      });
    }

    const register = async (email: string) => {
      const response = await server()
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName: 'Membre E2E' })
        .expect(201);
      return data<AuthResult>(response.body);
    };
    const member = await register(memberEmail);
    memberToken = member.tokens.accessToken;
    memberId = member.user.id;
    witnessToken = (await register(witnessEmail)).tokens.accessToken;

    // Fixture dédiée : la suite ne dépend jamais du seed (base CI vierge).
    const freeExercise = await ensureExerciseFixture(prisma, 'e2e-admin-moderation');
    freeExerciseSlug = freeExercise.slug;
    freeExerciseId = freeExercise.id;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.auditLog.deleteMany({
      where: { adminUser: { email: { in: [superEmail, supportEmail] } } },
    });
    await prisma.adminUser.deleteMany({ where: { email: { in: [superEmail, supportEmail] } } });
    await prisma.user.deleteMany({ where: { email: { in: [memberEmail, witnessEmail] } } });
    await prisma.exercise.deleteMany({ where: { slug: 'e2e-admin-moderation' } });
    await prisma.$disconnect();
    await app.close();
  });

  it('connexion admin : message uniforme en échec, rôles et permissions en succès', async () => {
    await server()
      .post('/api/v1/admin/auth/login')
      .send({ email: superEmail, password: 'MauvaisMotDePasse1!' })
      .expect(401);

    const login = data<AdminLoginResult>(
      (
        await server()
          .post('/api/v1/admin/auth/login')
          .send({ email: superEmail, password: ADMIN_PASSWORD })
          .expect(200)
      ).body,
    );
    superToken = login.accessToken;
    expect(login.admin.roles).toContain('superadmin');
    expect(login.admin.permissions).toEqual(expect.arrayContaining([...ADMIN_PERMISSIONS]));

    supportToken = data<AdminLoginResult>(
      (
        await server()
          .post('/api/v1/admin/auth/login')
          .send({ email: supportEmail, password: ADMIN_PASSWORD })
          .expect(200)
      ).body,
    ).accessToken;

    const me = data<AdminMe>(
      (await asAdmin(superToken).get('/api/v1/admin/auth/me').expect(200)).body,
    );
    expect(me.email).toBe(superEmail);
  });

  it('les jetons mobiles et admin ne sont JAMAIS interchangeables', async () => {
    // Jeton mobile sur une route admin : refusé.
    await asAdmin(memberToken).get('/api/v1/admin/users').expect(401);
    // Jeton admin sur une route mobile : refusé (audience différente).
    await server().get('/api/v1/users/me').set('Authorization', `Bearer ${superToken}`).expect(401);
    // Sans jeton : refusé.
    await server().get('/api/v1/admin/overview').expect(401);
  });

  it('RBAC : le support lit mais ne modifie pas', async () => {
    const users = data<ManagedUserSummary[]>(
      (
        await asAdmin(supportToken)
          .get(`/api/v1/admin/users?search=${encodeURIComponent(memberEmail)}`)
          .expect(200)
      ).body,
    );
    expect(users).toHaveLength(1);
    expect(users[0]?.email).toBe(memberEmail);

    await asAdmin(supportToken)
      .patch(`/api/v1/admin/users/${memberId}/status`)
      .send({ status: 'SUSPENDED' })
      .expect(403);
    await asAdmin(supportToken)
      .put(`/api/v1/admin/users/${memberId}/entitlements`)
      .send({ key: 'premium_exercises', isActive: true })
      .expect(403);
  });

  it('synthèse plateforme : compteurs cohérents', async () => {
    const overview = data<AdminOverview>(
      (await asAdmin(superToken).get('/api/v1/admin/overview').expect(200)).body,
    );
    expect(overview.usersCount).toBeGreaterThanOrEqual(2);
    expect(overview.publishedExercisesCount).toBeGreaterThan(0);
    expect(overview.exercisesCount).toBeGreaterThanOrEqual(overview.publishedExercisesCount);
  });

  it('attribution manuelle d’un droit : le membre devient premium, c’est audité', async () => {
    const detail = data<ManagedUserDetail>(
      (
        await asAdmin(superToken)
          .put(`/api/v1/admin/users/${memberId}/entitlements`)
          .send({ key: 'premium_exercises', isActive: true })
          .expect(200)
      ).body,
    );
    expect(detail.isPremium).toBe(true);

    // Côté membre : le droit est immédiatement actif (décision serveur).
    const entitlements = data<EntitlementsResponse>(
      (
        await server()
          .get('/api/v1/entitlements')
          .set('Authorization', `Bearer ${memberToken}`)
          .expect(200)
      ).body,
    );
    expect(entitlements.isPremium).toBe(true);
  });

  it('le back-office liste AUSSI les exercices non publiés', async () => {
    // Le catalogue mobile ne sert que le publié : sans cette route, un
    // exercice dépublié disparaîtrait de partout, y compris de l'écran censé
    // permettre de le republier.
    await asAdmin(superToken)
      .patch(`/api/v1/admin/exercises/${freeExerciseId}/publication`)
      .send({ isPublished: false })
      .expect(204);

    const hidden = data<AdminExerciseSummary[]>(
      (
        await asAdmin(superToken)
          .get(`/api/v1/admin/exercises?search=${encodeURIComponent(freeExerciseSlug)}`)
          .expect(200)
      ).body,
    );
    expect(hidden).toHaveLength(1);
    expect(hidden[0]?.isPublished).toBe(false);
    expect(hidden[0]?.image).toBeNull();

    await asAdmin(superToken)
      .patch(`/api/v1/admin/exercises/${freeExerciseId}/publication`)
      .send({ isPublished: true })
      .expect(204);
  });

  it('RBAC : le support ne voit pas le catalogue d’administration', async () => {
    await asAdmin(supportToken).get('/api/v1/admin/exercises').expect(403);
  });

  it('dépublication d’un exercice : invisible côté mobile, republication rétablit', async () => {
    await asAdmin(superToken)
      .patch(`/api/v1/admin/exercises/${freeExerciseId}/publication`)
      .send({ isPublished: false })
      .expect(204);
    await server()
      .get(`/api/v1/exercises/${freeExerciseSlug}`)
      .set('Authorization', `Bearer ${witnessToken}`)
      .expect(404);

    await asAdmin(superToken)
      .patch(`/api/v1/admin/exercises/${freeExerciseId}/publication`)
      .send({ isPublished: true })
      .expect(204);
    await server()
      .get(`/api/v1/exercises/${freeExerciseSlug}`)
      .set('Authorization', `Bearer ${witnessToken}`)
      .expect(200);
  });

  it('suppression d’un exercice : il quitte le catalogue, l’historique reste, la restauration le rend', async () => {
    // Suppression DOUCE : les séries déjà réalisées et les records citent
    // l'exercice. La route le fait disparaître de partout — y compris de la
    // liste d'administration — sans effacer une ligne d'historique.
    await asAdmin(superToken).delete(`/api/v1/admin/exercises/${freeExerciseId}`).expect(204);

    await server()
      .get(`/api/v1/exercises/${freeExerciseSlug}`)
      .set('Authorization', `Bearer ${witnessToken}`)
      .expect(404);

    const absent = data<AdminExerciseSummary[]>(
      (
        await asAdmin(superToken)
          .get(`/api/v1/admin/exercises?search=${encodeURIComponent(freeExerciseSlug)}`)
          .expect(200)
      ).body,
    );
    expect(absent).toHaveLength(0);

    // Sauf si on les demande — sinon on ne pourrait plus jamais les restaurer.
    const shown = data<AdminExerciseSummary[]>(
      (
        await asAdmin(superToken)
          .get(
            `/api/v1/admin/exercises?includeDeleted=true&search=${encodeURIComponent(freeExerciseSlug)}`,
          )
          .expect(200)
      ).body,
    );
    expect(shown).toHaveLength(1);
    expect(shown[0]?.deletedAt).not.toBeNull();
    expect(shown[0]?.isPublished).toBe(false);

    // Deux suppressions de suite : la seconde n'a plus rien à supprimer.
    await asAdmin(superToken).delete(`/api/v1/admin/exercises/${freeExerciseId}`).expect(404);

    await asAdmin(superToken).post(`/api/v1/admin/exercises/${freeExerciseId}/restore`).expect(204);
    // Restauré DÉPUBLIÉ : la remise en ligne se décide.
    await asAdmin(superToken)
      .patch(`/api/v1/admin/exercises/${freeExerciseId}/publication`)
      .send({ isPublished: true })
      .expect(204);
    await server()
      .get(`/api/v1/exercises/${freeExerciseSlug}`)
      .set('Authorization', `Bearer ${witnessToken}`)
      .expect(200);
  });

  it('reclassement d’un exercice : les catégories remplacent les anciennes', async () => {
    const groups = await prisma.muscleGroup.findMany({ orderBy: { slug: 'asc' }, take: 2 });
    const [first, second] = groups;
    expect(first && second).toBeTruthy();

    const updated = data<AdminExerciseSummary>(
      (
        await asAdmin(superToken)
          .patch(`/api/v1/admin/exercises/${freeExerciseId}/categories`)
          .send({
            primaryMuscleGroupSlug: first!.slug,
            secondaryMuscleGroupSlugs: [second!.slug, first!.slug],
            equipmentSlugs: [],
          })
          .expect(200)
      ).body,
    );
    // Le principal repris en secondaire est écarté, sans erreur.
    expect(updated.primaryMuscleGroupSlug).toBe(first!.slug);
    expect(updated.muscleGroupSlugs.sort()).toEqual([first!.slug, second!.slug].sort());
    expect(updated.equipmentSlugs).toEqual([]);

    await asAdmin(superToken)
      .patch(`/api/v1/admin/exercises/${freeExerciseId}/categories`)
      .send({
        primaryMuscleGroupSlug: 'groupe-qui-nexiste-pas',
        secondaryMuscleGroupSlugs: [],
        equipmentSlugs: [],
      })
      .expect(400);
  });

  it('catégories : création, renommage, et refus de supprimer une catégorie encore principale', async () => {
    const slug = `e2e-categorie-${randomUUID().slice(0, 8)}`;
    const created = await asAdmin(superToken)
      .post('/api/v1/admin/muscle-groups')
      .send({ slug, name: 'Catégorie de test', sortOrder: 42 })
      .expect(201);
    const groupId = (created.body as { id: string }).id;

    // Slug déjà pris : refusé, pas de doublon silencieux.
    await asAdmin(superToken)
      .post('/api/v1/admin/muscle-groups')
      .send({ slug, name: 'Doublon' })
      .expect(409);

    await asAdmin(superToken)
      .patch(`/api/v1/admin/muscle-groups/${groupId}`)
      .send({ name: 'Catégorie renommée' })
      .expect(204);

    const listed = (await asAdmin(superToken).get('/api/v1/admin/muscle-groups').expect(200))
      .body as { id: string; name: string; primaryExercisesCount: number }[];
    const mine = listed.find((group) => group.id === groupId);
    expect(mine?.name).toBe('Catégorie renommée');
    expect(mine?.primaryExercisesCount).toBe(0);

    // Une catégorie encore principale ne se supprime pas : la contrainte de
    // base est en cascade, les exercices resteraient sans muscle principal.
    const populated = listed.find((group) => group.primaryExercisesCount > 0);
    expect(populated).toBeDefined();
    await asAdmin(superToken).delete(`/api/v1/admin/muscle-groups/${populated!.id}`).expect(409);

    await asAdmin(superToken).delete(`/api/v1/admin/muscle-groups/${groupId}`).expect(204);
    await asAdmin(superToken).delete(`/api/v1/admin/muscle-groups/${groupId}`).expect(404);
  });

  it('suspension : sessions révoquées immédiatement, reconnexion refusée, audit tracé', async () => {
    const summary = data<ManagedUserSummary>(
      (
        await asAdmin(superToken)
          .patch(`/api/v1/admin/users/${memberId}/status`)
          .send({ status: 'SUSPENDED' })
          .expect(200)
      ).body,
    );
    expect(summary.status).toBe('SUSPENDED');

    // Le jeton du membre meurt aussitôt (session révoquée).
    await server()
      .get('/api/v1/entitlements')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(401);
    // Et la reconnexion est refusée tant que le compte est suspendu.
    await server()
      .post('/api/v1/auth/login')
      .send({ email: memberEmail, password: 'MotDePasseSolide42' })
      .expect(401);

    const logs = data<AdminAuditLog[]>(
      (await asAdmin(superToken).get('/api/v1/admin/audit-logs?limit=50').expect(200)).body,
    );
    const suspension = logs.find(
      (log) => log.action === 'admin.user_suspended' && log.userId === memberId,
    );
    expect(suspension).toBeDefined();
    expect(suspension?.actorType).toBe('ADMIN');

    // Réactivation : la connexion fonctionne à nouveau.
    await asAdmin(superToken)
      .patch(`/api/v1/admin/users/${memberId}/status`)
      .send({ status: 'ACTIVE' })
      .expect(200);
    await server()
      .post('/api/v1/auth/login')
      .send({ email: memberEmail, password: 'MotDePasseSolide42' })
      .expect(200);
  });
});

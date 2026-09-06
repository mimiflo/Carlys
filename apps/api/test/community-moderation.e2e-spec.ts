process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  ADMIN_PERMISSIONS,
  type AdminAuditLog,
  type AdminCommunityReport,
  type AdminLoginResult,
  type ApiSuccessEnvelope,
  type AuthResult,
  type BlockedUser,
  type CommunityFriend,
  type CommunityProfile,
  type CommunityReport,
  type Encouragement,
  type FriendRequest,
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

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Modération de la communauté : retrait d'un encouragement, signalements,
 * blocages OPAQUES, et leur lecture côté back-office.
 *
 * Suite dans sa propre application : elle envoie quatre demandes d'ami
 * (seau dédié de 10/min) et fait deux connexions admin (seau de 10/min
 * aussi), des budgets qu'elle ne veut partager avec personne.
 */
describe('Modération de la communauté (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let tokenC: string;
  let userIdA: string;
  let userIdB: string;
  let superToken: string;
  let readerToken: string;
  let reportId: string;
  let reportedEncouragementId: string;

  const emailA = `e2e-moderation-a-${randomUUID()}@carlys.test`;
  const emailB = `e2e-moderation-b-${randomUUID()}@carlys.test`;
  const emailC = `e2e-moderation-c-${randomUUID()}@carlys.test`;
  const superEmail = `e2e-moderation-super-${randomUUID()}@carlys.test`;
  const readerEmail = `e2e-moderation-lecteur-${randomUUID()}@carlys.test`;
  const readerRoleSlug = `e2e-lecteur-${randomUUID().slice(0, 8)}`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const authed = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) => server().patch(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });
  const feedOf = async (token: string): Promise<Encouragement[]> =>
    data<Encouragement[]>((await authed(token).get('/api/v1/community/feed').expect(200)).body);
  const friendsOf = async (token: string): Promise<CommunityFriend[]> =>
    data<CommunityFriend[]>(
      (await authed(token).get('/api/v1/community/friends').expect(200)).body,
    );
  const receivedBy = async (token: string): Promise<FriendRequest[]> =>
    data<FriendRequest[]>((await authed(token).get('/api/v1/community/requests').expect(200)).body);
  const encourage = (token: string, recipientUserId: string, message: string) =>
    authed(token)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId, message })
      .expect(201);

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = async (email: string, displayName: string): Promise<AuthResult> => {
      const response = await server()
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName })
        .expect(201);
      return data<AuthResult>(response.body);
    };
    const a = await register(emailA, 'Alice');
    const b = await register(emailB, 'Boris');
    const c = await register(emailC, 'Chloé');
    tokenA = a.tokens.accessToken;
    tokenB = b.tokens.accessToken;
    tokenC = c.tokens.accessToken;
    userIdA = a.user.id;
    userIdB = b.user.id;

    // RBAC : mêmes upserts idempotents que le seed (suite autonome). Le
    // « lecteur » ne porte pas community:moderate : c'est lui qui prouve le 403.
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
    const readerRole = await roleOf(readerRoleSlug, 'Lecteur E2E', ['user:read']);
    const passwordHash = await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id });
    for (const [email, role] of [
      [superEmail, superRole],
      [readerEmail, readerRole],
    ] as const) {
      const admin = await prisma.adminUser.create({
        data: { email, displayName: 'Admin E2E', passwordHash },
      });
      await prisma.adminUserRole.create({ data: { adminUserId: admin.id, roleId: role.id } });
    }
    const loginAdmin = async (email: string): Promise<string> =>
      data<AdminLoginResult>(
        (
          await server()
            .post('/api/v1/admin/auth/login')
            .send({ email, password: ADMIN_PASSWORD })
            .expect(200)
        ).body,
      ).accessToken;
    superToken = await loginAdmin(superEmail);
    readerToken = await loginAdmin(readerEmail);
  });

  afterAll(async () => {
    await prisma.auditLog.deleteMany({
      where: { adminUser: { email: { in: [superEmail, readerEmail] } } },
    });
    await prisma.adminUser.deleteMany({ where: { email: { in: [superEmail, readerEmail] } } });
    await prisma.adminRole.deleteMany({ where: { slug: readerRoleSlug } });
    // Blocages, signalements et encouragements suivent les comptes (cascade).
    await prisma.user.deleteMany({ where: { email: { in: [emailA, emailB, emailC] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('un encouragement se retire par son destinataire ou son auteur, jamais par un tiers', async () => {
    await authed(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
    const [received] = await receivedBy(tokenB);
    await authed(tokenB).post(`/api/v1/community/requests/${received?.id}/accept`).expect(204);

    await encourage(tokenA, userIdB, 'Premier');
    await encourage(tokenA, userIdB, 'Deuxième');
    let feed = await feedOf(tokenB);
    expect(feed.map((entry) => entry.message)).toEqual(['Deuxième', 'Premier']);
    const first = feed[1]?.id ?? '';
    const second = feed[0]?.id ?? '';

    // Chloé n'est ni l'auteur ni le destinataire : 204 opaque, rien ne bouge.
    await authed(tokenC).delete(`/api/v1/community/encouragements/${first}`).expect(204);
    expect(await feedOf(tokenB)).toHaveLength(2);

    // Le destinataire retire ce qu'il ne veut plus lire.
    await authed(tokenB).delete(`/api/v1/community/encouragements/${first}`).expect(204);
    feed = await feedOf(tokenB);
    expect(feed.map((entry) => entry.message)).toEqual(['Deuxième']);

    // L'auteur retire ce qu'il a écrit ; rejouer aboutit pareil.
    await authed(tokenA).delete(`/api/v1/community/encouragements/${second}`).expect(204);
    expect(await feedOf(tokenB)).toHaveLength(0);
    await authed(tokenB).delete(`/api/v1/community/encouragements/${second}`).expect(204);
  });

  it('signaler : accusé de réception, doublon ouvert rendu tel quel, garde-fous', async () => {
    await encourage(tokenA, userIdB, 'Message à signaler');
    reportedEncouragementId = (await feedOf(tokenB))[0]?.id ?? '';

    const report = data<CommunityReport>(
      (
        await authed(tokenB)
          .post('/api/v1/community/reports')
          .send({
            reportedUserId: userIdA,
            encouragementId: reportedEncouragementId,
            reason: 'HARCELEMENT',
            details: '  Il insiste.  ',
          })
          .expect(201)
      ).body,
    );
    expect(report.status).toBe('OPEN');
    expect(report.details).toBe('Il insiste.');
    expect(report.reportedUserId).toBe(userIdA);
    reportId = report.id;

    // Rejouer le même signalement rend le même accusé de réception.
    const replay = data<CommunityReport>(
      (
        await authed(tokenB)
          .post('/api/v1/community/reports')
          .send({
            reportedUserId: userIdA,
            encouragementId: reportedEncouragementId,
            reason: 'SPAM',
          })
          .expect(201)
      ).body,
    );
    expect(replay.id).toBe(reportId);
    expect(replay.reason).toBe('HARCELEMENT');

    // Chloé n'a pas reçu ce message : elle ne peut pas le viser.
    await authed(tokenC)
      .post('/api/v1/community/reports')
      .send({ reportedUserId: userIdA, encouragementId: reportedEncouragementId, reason: 'SPAM' })
      .expect(404);
    await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ reportedUserId: userIdB, reason: 'AUTRE' })
      .expect(400);
    await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ reportedUserId: userIdA, reason: 'AUTRE', details: 'x'.repeat(501) })
      .expect(400);
    await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ reportedUserId: userIdA, reason: 'INCONNU' })
      .expect(400);
    await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ reportedUserId: randomUUID(), reason: 'AUTRE' })
      .expect(404);
  });

  it('bloquer : amitié retirée, réponses opaques partout, liste, déblocage', async () => {
    const profileB = data<CommunityProfile>(
      (await authed(tokenB).get('/api/v1/community/profile').expect(200)).body,
    );

    await authed(tokenB).post(`/api/v1/community/blocks/${userIdA}`).expect(204);

    // L'amitié a disparu des deux côtés, et le fil de Boris tait Alice.
    expect(await friendsOf(tokenA)).toHaveLength(0);
    expect(await friendsOf(tokenB)).toHaveLength(0);
    expect(await feedOf(tokenB)).toHaveLength(0);

    // Pour Alice, Boris n'existe plus : demande muette, code inconnu, 403.
    await authed(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
    expect(await receivedBy(tokenB)).toHaveLength(0);
    await authed(tokenA).get(`/api/v1/community/friend-codes/${profileB.friendCode}`).expect(404);
    await authed(tokenA)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId: userIdB, message: 'Réponds-moi.' })
      .expect(403);

    // Et dans l'autre sens aussi : Boris ne peut pas non plus la joindre.
    await authed(tokenB).post('/api/v1/community/requests').send({ email: emailA }).expect(202);
    expect(await receivedBy(tokenA)).toHaveLength(0);

    const blocks = data<BlockedUser[]>(
      (await authed(tokenB).get('/api/v1/community/blocks').expect(200)).body,
    );
    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toMatchObject({ userId: userIdA, displayName: 'Alice' });

    // Idempotent, et les garde-fous.
    await authed(tokenB).post(`/api/v1/community/blocks/${userIdA}`).expect(204);
    await authed(tokenB).post(`/api/v1/community/blocks/${userIdB}`).expect(400);
    await authed(tokenB).post(`/api/v1/community/blocks/${randomUUID()}`).expect(404);

    // Débloquer : rien n'est rétabli, mais tout redevient possible.
    await authed(tokenB).delete(`/api/v1/community/blocks/${userIdA}`).expect(204);
    await authed(tokenB).delete(`/api/v1/community/blocks/${userIdA}`).expect(204);
    expect(
      await authed(tokenB)
        .get('/api/v1/community/blocks')
        .expect(200)
        .then((r) => data<BlockedUser[]>(r.body)),
    ).toHaveLength(0);
    expect(await friendsOf(tokenB)).toHaveLength(0);
    expect((await feedOf(tokenB)).map((entry) => entry.message)).toEqual(['Message à signaler']);

    await authed(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
    expect((await receivedBy(tokenB)).map((entry) => entry.fromDisplayName)).toEqual(['Alice']);
  });

  it('administration : lecture des signalements, résolution auditée, permission dédiée', async () => {
    // Sans la permission dédiée : 403 ; avec un jeton mobile : 401.
    await authed(readerToken).get('/api/v1/admin/community/reports').expect(403);
    await authed(tokenB).get('/api/v1/admin/community/reports').expect(401);

    const open = data<AdminCommunityReport[]>(
      (await authed(superToken).get('/api/v1/admin/community/reports?status=OPEN').expect(200))
        .body,
    );
    const mine = open.find((entry) => entry.id === reportId);
    expect(mine).toBeDefined();
    expect(mine?.reporter.email).toBe(emailB);
    expect(mine?.reportedUser).toMatchObject({ id: userIdA, email: emailA, displayName: 'Alice' });
    expect(mine?.encouragementMessage).toBe('Message à signaler');
    expect(mine?.details).toBe('Il insiste.');

    const resolved = data<AdminCommunityReport>(
      (
        await authed(superToken)
          .patch(`/api/v1/admin/community/reports/${reportId}`)
          .send({ status: 'RESOLVED' })
          .expect(200)
      ).body,
    );
    expect(resolved.status).toBe('RESOLVED');
    expect(resolved.resolvedAt).not.toBeNull();
    // Rejouer : même réponse, sans second audit.
    await authed(superToken)
      .patch(`/api/v1/admin/community/reports/${reportId}`)
      .send({ status: 'RESOLVED' })
      .expect(200);

    const stillOpen = data<AdminCommunityReport[]>(
      (await authed(superToken).get('/api/v1/admin/community/reports?status=OPEN').expect(200))
        .body,
    );
    expect(stillOpen.some((entry) => entry.id === reportId)).toBe(false);
    const done = data<AdminCommunityReport[]>(
      (
        await authed(superToken)
          .get('/api/v1/admin/community/reports?status=RESOLVED&limit=5')
          .expect(200)
      ).body,
    );
    expect(done.some((entry) => entry.id === reportId)).toBe(true);

    const logs = data<AdminAuditLog[]>(
      (await authed(superToken).get('/api/v1/admin/audit-logs?limit=50').expect(200)).body,
    );
    const audited = logs.filter(
      (log) => log.action === 'admin.community_report_resolved' && log.resourceId === reportId,
    );
    expect(audited).toHaveLength(1);
    expect(audited[0]?.userId).toBe(userIdA);

    await authed(superToken)
      .patch(`/api/v1/admin/community/reports/${randomUUID()}`)
      .send({ status: 'RESOLVED' })
      .expect(404);
    await authed(superToken)
      .patch(`/api/v1/admin/community/reports/${reportId}`)
      .send({ status: 'FERME' })
      .expect(400);
    await authed(superToken).get('/api/v1/admin/community/reports?status=FERME').expect(400);
  });
});

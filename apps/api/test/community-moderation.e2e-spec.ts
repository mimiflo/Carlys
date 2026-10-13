process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  ADMIN_PERMISSIONS,
  type AdminAuditLog,
  type AdminCommunityReport,
  type ApiSuccessEnvelope,
  type AuthResult,
  type BlockedUser,
  type CommunityFriend,
  type CommunityProfile,
  type CommunityReport,
  type Encouragement,
  type FriendChallenge,
  type FriendRequest,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createAdminAccount } from './support/admin-fixture';
import { adminSession } from './support/admin-session';
import { reinitialiserDebit } from './support/throttle';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { AuditService } from '../src/modules/audit/audit.service';
import { configureApp } from '../src/app/configure-app';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Modération de la communauté : retrait d'un encouragement, signalements,
 * blocages OPAQUES, et leur lecture côté back-office.
 *
 * Suite dans sa propre application : elle envoie des demandes d'ami et des
 * signalements (seaux dédiés de 10/min, remis à zéro avant chaque test) et
 * fait trois connexions admin (seau de 10/min aussi).
 *
 * Les décisions (retrait, suspension) se jouent en fin de suite sur leurs
 * propres comptes — Dina, Émile, Fanny : suspendre Émile révoque ses
 * sessions, ce que les scénarios d'Alice et Boris n'ont pas à subir.
 */
describe('Modération de la communauté (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let tokenC: string;
  let userIdA: string;
  let userIdB: string;
  let userIdC: string;
  let superToken: string;
  let readerToken: string;
  let moderatorToken: string;
  let reportId: string;
  let reportedEncouragementId: string;

  const emailA = `e2e-moderation-a-${randomUUID()}@carlys.test`;
  const emailB = `e2e-moderation-b-${randomUUID()}@carlys.test`;
  const emailC = `e2e-moderation-c-${randomUUID()}@carlys.test`;
  const superEmail = `e2e-moderation-super-${randomUUID()}@carlys.test`;
  const readerEmail = `e2e-moderation-lecteur-${randomUUID()}@carlys.test`;
  const readerRoleSlug = `e2e-lecteur-${randomUUID().slice(0, 8)}`;
  const moderatorEmail = `e2e-moderation-moderateur-${randomUUID()}@carlys.test`;
  const moderatorRoleSlug = `e2e-moderateur-${randomUUID().slice(0, 8)}`;
  const emailD = `e2e-moderation-d-${randomUUID()}@carlys.test`;
  const emailE = `e2e-moderation-e-${randomUUID()}@carlys.test`;
  const emailF = `e2e-moderation-f-${randomUUID()}@carlys.test`;
  const adminEmails = () => [superEmail, readerEmail, moderatorEmail];

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
    userIdC = c.user.id;

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
      (await adminSession(server, email, ADMIN_PASSWORD)).accessToken;
    // Modérateur SANS user:update : il tranche, mais ne suspend pas.
    await createAdminAccount(prisma, {
      email: moderatorEmail,
      password: ADMIN_PASSWORD,
      roleSlug: moderatorRoleSlug,
      permissions: ['community:moderate'],
    });
    superToken = await loginAdmin(superEmail);
    readerToken = await loginAdmin(readerEmail);
    moderatorToken = await loginAdmin(moderatorEmail);
  });

  beforeEach(reinitialiserDebit);

  afterAll(async () => {
    // L'APPLICATION SE FERME EN PREMIER, et l'ordre n'est pas cosmétique.
    // `app.close()` draine les écritures d'audit encore en vol
    // (`AuditService.onModuleDestroy`). Nettoyer AVANT, comme ici
    // auparavant, laissait trois atterrissages possibles à la dernière
    // écriture : avant la suppression — le cas nominal ; entre la
    // suppression du journal et celle du compte — la ligne survivait au
    // nettoyage d'une base que les suites PARTAGENT ; ou après la
    // suppression du compte — l'INSERT violait alors la clé étrangère, et
    // `AuditService` avalait l'erreur dans son `catch`. Fermer d'abord rend
    // le nettoyage exact : plus rien ne s'écrit derrière lui.
    await app.close();
    await prisma.auditLog.deleteMany({
      where: { adminUser: { email: { in: adminEmails() } } },
    });
    await prisma.adminUser.deleteMany({ where: { email: { in: adminEmails() } } });
    await prisma.adminRole.deleteMany({
      where: { slug: { in: [readerRoleSlug, moderatorRoleSlug] } },
    });
    // Blocages, signalements et encouragements suivent les comptes (cascade).
    await prisma.user.deleteMany({
      where: { email: { in: [emailA, emailB, emailC, emailD, emailE, emailF] } },
    });
    await prisma.$disconnect();
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

  it('la preuve d’un signalement survit au retrait du message par son auteur', async () => {
    // Alice retire le message signalé : il quitte le fil de Boris (204 opaque)...
    await authed(tokenA)
      .delete(`/api/v1/community/encouragements/${reportedEncouragementId}`)
      .expect(204);
    expect(await feedOf(tokenB)).toHaveLength(0);

    // ...mais l'administration lit encore ce qui a été signalé, référence ou pas.
    const open = data<AdminCommunityReport[]>(
      (await authed(superToken).get('/api/v1/admin/community/reports?status=OPEN').expect(200))
        .body,
    );
    const mine = open.find((entry) => entry.id === reportId);
    expect(mine).toMatchObject({
      encouragementId: null,
      encouragementMessage: 'Message à signaler',
    });
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

    // Même raison qu'en authentification : l'audit s'écrit sans bloquer la
    // réponse, donc relire immédiatement courait contre la promesse.
    // Le RÉSULTAT est lu, pas jeté. `flush` garantit que l'écriture a été
    // TENTÉE, jamais qu'elle a réussi : son `catch` transforme un `create`
    // rejeté en promesse résolue. Sans cette assertion, une violation de clé
    // étrangère ou un pool saturé rendrait un flush parfaitement normal suivi
    // d'une relecture vide — le symptôme EXACT de la course que flush corrige,
    // et le prochain échec serait diagnostiqué à tort comme « elle est revenue ».
    expect(await app.get(AuditService).flush()).toEqual({
      abandonnees: 0,
      echouees: 0,
    });
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

  it('signaler un défi entre amis : membre seulement, créateur seulement, clichés figés', async () => {
    // Alice et Boris redeviennent amis (la demande d'Alice attend depuis le
    // déblocage), puis Alice défie Boris avec un mot.
    const [pending] = await receivedBy(tokenB);
    await authed(tokenB).post(`/api/v1/community/requests/${pending?.id}/accept`).expect(204);
    const challengeId = randomUUID();
    const challenge = data<FriendChallenge>(
      (
        await authed(tokenA)
          .post('/api/v1/community/friend-challenges')
          .send({
            id: challengeId,
            title: 'Qui court le plus',
            metric: 'DISTANCE_METERS',
            durationDays: 7,
            message: '  Tu vas encore perdre, comme d’habitude.  ',
            invitedUserIds: [userIdB],
          })
          .expect(201)
      ).body,
    );
    expect(challenge.message).toBe('Tu vas encore perdre, comme d’habitude.');

    // Boris REFUSE le défi : il l'a lu, il peut le signaler quand même.
    await authed(tokenB)
      .delete(`/api/v1/community/friend-challenges/${challengeId}/join`)
      .expect(204);
    const reportBody = {
      reportedUserId: userIdA,
      friendChallengeId: challengeId,
      reason: 'CONTENU_INAPPROPRIE',
    };
    const report = data<CommunityReport>(
      (await authed(tokenB).post('/api/v1/community/reports').send(reportBody).expect(201)).body,
    );
    expect(report).toMatchObject({
      reportedUserId: userIdA,
      friendChallengeId: challengeId,
      encouragementId: null,
      status: 'OPEN',
    });
    // Les clichés sont en base, pris dans la transaction du signalement.
    const stored = await prisma.communityReport.findUniqueOrThrow({ where: { id: report.id } });
    expect(stored).toMatchObject({
      friendChallengeId: challengeId,
      friendChallengeTitle: 'Qui court le plus',
      friendChallengeMessage: 'Tu vas encore perdre, comme d’habitude.',
      encouragementMessage: null,
    });

    // Rejouer rend le même accusé : pas de doublon pour l'administration.
    const replay = data<CommunityReport>(
      (await authed(tokenB).post('/api/v1/community/reports').send(reportBody).expect(201)).body,
    );
    expect(replay.id).toBe(report.id);

    // Chloé n'en est pas membre : 404. Boris qui accuse Chloé, qui n'en est
    // pas la créatrice : 404 aussi, et le MÊME message — pas d'oracle.
    const notMember = await authed(tokenC)
      .post('/api/v1/community/reports')
      .send(reportBody)
      .expect(404);
    const notCreator = await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ ...reportBody, reportedUserId: userIdC })
      .expect(404);
    const unknown = await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ ...reportBody, friendChallengeId: randomUUID() })
      .expect(404);
    const messageOf = (body: unknown) => (body as { error: { message: string } }).error.message;
    expect(messageOf(notMember.body)).toBe('Défi introuvable.');
    expect(messageOf(notCreator.body)).toBe(messageOf(notMember.body));
    expect(messageOf(unknown.body)).toBe(messageOf(notMember.body));

    // Un encouragement ET un défi : 400. Son propre défi : 400 (soi-même).
    await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ ...reportBody, encouragementId: randomUUID() })
      .expect(400);
    await authed(tokenA)
      .post('/api/v1/community/reports')
      .send({ ...reportBody, reportedUserId: userIdA })
      .expect(400);
    await authed(tokenB)
      .post('/api/v1/community/reports')
      .send({ ...reportBody, friendChallengeId: 'pas-un-uuid' })
      .expect(400);

    // L'administration lit les clichés, même une fois le défi disparu.
    await prisma.friendChallenge.delete({ where: { id: challengeId } });
    const open = data<AdminCommunityReport[]>(
      (await authed(superToken).get('/api/v1/admin/community/reports?status=OPEN').expect(200))
        .body,
    );
    expect(open.find((entry) => entry.id === report.id)).toMatchObject({
      friendChallengeId: null,
      friendChallengeTitle: 'Qui court le plus',
      friendChallengeMessage: 'Tu vas encore perdre, comme d’habitude.',
      encouragementMessage: null,
      reportedUser: { id: userIdA },
    });
  });

  describe('décisions de modération', () => {
    let tokenD: string;
    let tokenE: string;
    let tokenF: string;
    let userIdD: string;
    let userIdE: string;
    let userIdF: string;
    let encouragementReportId: string;
    let personReportId: string;
    let challengeId: string;

    const decide = (token: string, id: string, body: object) =>
      authed(token).post(`/api/v1/admin/community/reports/${id}/decision`).send(body);
    const reportsOf = async (filters: string): Promise<AdminCommunityReport[]> =>
      data<AdminCommunityReport[]>(
        (await authed(superToken).get(`/api/v1/admin/community/reports?${filters}`).expect(200))
          .body,
      );
    const auditLogs = async (): Promise<AdminAuditLog[]> => {
      expect(await app.get(AuditService).flush()).toEqual({ abandonnees: 0, echouees: 0 });
      return data<AdminAuditLog[]>(
        (await authed(superToken).get('/api/v1/admin/audit-logs?limit=100').expect(200)).body,
      );
    };
    const fileReport = async (token: string, body: object): Promise<string> =>
      data<CommunityReport>(
        (await authed(token).post('/api/v1/community/reports').send(body).expect(201)).body,
      ).id;

    beforeAll(async () => {
      const register = async (email: string, displayName: string): Promise<AuthResult> =>
        data<AuthResult>(
          (
            await server()
              .post('/api/v1/auth/register')
              .send({ email, password: 'MotDePasseSolide42', displayName })
              .expect(201)
          ).body,
        );
      const d = await register(emailD, 'Dina');
      const e = await register(emailE, 'Émile');
      const f = await register(emailF, 'Fanny');
      [tokenD, tokenE, tokenF] = [d, e, f].map((auth) => auth.tokens.accessToken) as [
        string,
        string,
        string,
      ];
      userIdD = d.user.id;
      userIdE = e.user.id;
      userIdF = f.user.id;
      // Émile devient l'ami de Dina et de Fanny.
      for (const [token, email] of [
        [tokenD, emailD],
        [tokenF, emailF],
      ] as const) {
        await authed(tokenE).post('/api/v1/community/requests').send({ email }).expect(202);
        const [pending] = await receivedBy(token);
        await authed(token).post(`/api/v1/community/requests/${pending?.id}/accept`).expect(204);
      }
    });

    it('retirer un encouragement : supprimé du fil, décision lisible, audit sans texte', async () => {
      await encourage(tokenE, userIdD, 'Message à retirer');
      const [received] = await feedOf(tokenD);
      encouragementReportId = await fileReport(tokenD, {
        reportedUserId: userIdE,
        encouragementId: received?.id,
        reason: 'HARCELEMENT',
      });
      personReportId = await fileReport(tokenD, { reportedUserId: userIdE, reason: 'AUTRE' });

      const decided = data<AdminCommunityReport>(
        (
          await decide(superToken, encouragementReportId, {
            removeContent: true,
            suspendUser: false,
            note: '  Propos insultants.  ',
          }).expect(200)
        ).body,
      );
      expect(decided).toMatchObject({
        status: 'RESOLVED',
        contentRemoved: true,
        userSuspended: false,
        resolutionNote: 'Propos insultants.',
        resolvedBy: { email: superEmail, displayName: 'Admin E2E' },
        encouragementId: null,
        encouragementMessage: 'Message à retirer',
        reportedUserStatus: 'ACTIVE',
        reportedUserReportsCount: 2,
        reportedUserOpenReportsCount: 1,
      });
      expect(decided.resolvedAt).not.toBeNull();
      expect(await feedOf(tokenD)).toHaveLength(0);
      // Le signalement de la personne en général n'est pas un frère : il reste ouvert.
      expect((await reportsOf(`reportedUserId=${userIdE}&status=OPEN`)).map((r) => r.id)).toEqual([
        personReportId,
      ]);

      // Rejouer sur un signalement tranché : 409. Retirer « la personne » : 400.
      await decide(superToken, encouragementReportId, {
        removeContent: false,
        suspendUser: false,
      }).expect(409);
      await decide(superToken, personReportId, { removeContent: true, suspendUser: false }).expect(
        400,
      );
      await decide(superToken, randomUUID(), { removeContent: false, suspendUser: false }).expect(
        404,
      );
      await decide(superToken, personReportId, { removeContent: 'oui', suspendUser: false }).expect(
        400,
      );
      await decide(superToken, personReportId, {
        removeContent: false,
        suspendUser: false,
        note: 'x'.repeat(501),
      }).expect(400);
      await decide(superToken, personReportId, {
        removeContent: false,
        suspendUser: false,
        inconnu: true,
      }).expect(400);
      await decide(readerToken, personReportId, {
        removeContent: false,
        suspendUser: false,
      }).expect(403);

      const logs = await auditLogs();
      expect(
        logs.find(
          (log) =>
            log.action === 'admin.community_report_decided' &&
            log.resourceId === encouragementReportId,
        )?.metadata,
      ).toEqual({
        reason: 'HARCELEMENT',
        removeContent: true,
        suspendUser: false,
        userSuspended: false,
        siblingReportsResolved: 0,
        siblingReportIds: [],
      });
      const removal = logs.find(
        (log) => log.action === 'admin.community_content_removed' && log.userId === userIdE,
      );
      expect(removal).toMatchObject({ resourceType: 'encouragement', resourceId: received?.id });
      expect(JSON.stringify(logs)).not.toContain('Message à retirer');
      expect(JSON.stringify(logs)).not.toContain('Propos insultants');
    });

    it('retirer le mot d’un défi : titre gardé, message nul pour les membres, signalements frères résolus', async () => {
      challengeId = randomUUID();
      await authed(tokenE)
        .post('/api/v1/community/friend-challenges')
        .send({
          id: challengeId,
          title: 'Qui court le plus',
          metric: 'DISTANCE_METERS',
          durationDays: 7,
          message: 'Vous êtes nuls.',
          invitedUserIds: [userIdD, userIdF],
        })
        .expect(201);
      const target = { reportedUserId: userIdE, friendChallengeId: challengeId };
      const fromD = await fileReport(tokenD, { ...target, reason: 'CONTENU_INAPPROPRIE' });
      const fromF = await fileReport(tokenF, { ...target, reason: 'HARCELEMENT' });

      await decide(moderatorToken, fromD, { removeContent: true, suspendUser: false }).expect(200);

      const challenge = data<FriendChallenge>(
        (await authed(tokenD).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200))
          .body,
      );
      expect(challenge.title).toBe('Qui court le plus');
      expect(challenge.message).toBeNull();
      const stored = await prisma.friendChallenge.findUniqueOrThrow({ where: { id: challengeId } });
      expect(stored.messageRemovedAt).not.toBeNull();

      const [sibling] = (await reportsOf(`reportedUserId=${userIdE}&reason=HARCELEMENT`)).filter(
        (report) => report.id === fromF,
      );
      expect(sibling).toMatchObject({
        status: 'RESOLVED',
        contentRemoved: true,
        friendChallengeMessageRemoved: true,
        // La preuve reste : le cliché du mot n'est pas effacé avec lui.
        friendChallengeMessage: 'Vous êtes nuls.',
        resolvedBy: { email: moderatorEmail },
      });
      // Plus rien à retirer sur ce défi : un signalement rouvert le dit (409),
      // et ce 409 ne suspend personne, même suspension demandée.
      await authed(superToken)
        .patch(`/api/v1/admin/community/reports/${fromF}`)
        .send({ status: 'OPEN' })
        .expect(200);
      await decide(superToken, fromF, { removeContent: true, suspendUser: false }).expect(409);
      await decide(superToken, fromF, {
        removeContent: true,
        suspendUser: true,
        note: 'Récidive.',
      }).expect(409);
      await authed(tokenE).get('/api/v1/community/feed').expect(200);
      expect((await prisma.user.findUniqueOrThrow({ where: { id: userIdE } })).status).toBe(
        'ACTIVE',
      );
      // Rouvrir garde la décision comme historique...
      const [reopened] = (await reportsOf(`reportedUserId=${userIdE}&status=OPEN`)).filter(
        (report) => report.id === fromF,
      );
      expect(reopened).toMatchObject({
        resolvedAt: null,
        contentRemoved: true,
        resolvedBy: { email: moderatorEmail },
      });
      // ...mais la résoudre SANS décision l'efface : celle du modérateur ne
      // s'affiche pas sous le nom d'un autre.
      const plain = data<AdminCommunityReport>(
        (
          await authed(superToken)
            .patch(`/api/v1/admin/community/reports/${fromF}`)
            .send({ status: 'RESOLVED' })
            .expect(200)
        ).body,
      );
      expect(plain).toMatchObject({
        status: 'RESOLVED',
        resolvedBy: { email: superEmail },
        resolutionNote: null,
        contentRemoved: false,
        userSuspended: false,
      });

      const logs = await auditLogs();
      expect(
        logs.find(
          (log) => log.action === 'admin.community_report_decided' && log.resourceId === fromD,
        )?.metadata,
      ).toMatchObject({ siblingReportsResolved: 1, siblingReportIds: [fromF] });
      expect(
        logs.find(
          (log) =>
            log.action === 'admin.community_content_removed' && log.resourceId === challengeId,
        ),
      ).toMatchObject({ resourceType: 'friend_challenge' });
    });

    it('suspendre : note obligatoire, permission user:update exigée, sessions révoquées', async () => {
      await decide(superToken, personReportId, { removeContent: false, suspendUser: true }).expect(
        400,
      );
      await decide(superToken, personReportId, {
        removeContent: false,
        suspendUser: true,
        note: '   ',
      }).expect(400);
      // Le modérateur sans user:update tranche, mais ne suspend pas.
      await decide(moderatorToken, personReportId, {
        removeContent: false,
        suspendUser: true,
        note: 'Récidive.',
      }).expect(403);
      await authed(tokenE).get('/api/v1/community/feed').expect(200);

      const decided = data<AdminCommunityReport>(
        (
          await decide(superToken, personReportId, {
            removeContent: false,
            suspendUser: true,
            note: 'Récidive après retrait.',
          }).expect(200)
        ).body,
      );
      expect(decided).toMatchObject({
        status: 'RESOLVED',
        userSuspended: true,
        contentRemoved: false,
        reportedUserStatus: 'SUSPENDED',
      });
      await authed(tokenE).get('/api/v1/community/feed').expect(401);

      const logs = await auditLogs();
      expect(
        logs.some((log) => log.action === 'admin.user_suspended' && log.userId === userIdE),
      ).toBe(true);
    });

    it('filtres par motif et par personne, compteurs par personne', async () => {
      await fileReport(tokenF, { reportedUserId: userIdE, reason: 'SPAM' });

      const spam = await reportsOf(`reportedUserId=${userIdE}&reason=SPAM`);
      expect(spam).toHaveLength(1);
      expect(spam[0]).toMatchObject({
        reason: 'SPAM',
        reportedUser: { id: userIdE },
        reportedUserStatus: 'SUSPENDED',
        // L'encouragement, la personne, le défi (deux fois), le spam ; seul
        // ce dernier est encore ouvert.
        reportedUserReportsCount: 5,
        reportedUserOpenReportsCount: 1,
      });
      const all = await reportsOf(`reportedUserId=${userIdE}`);
      expect(all).toHaveLength(5);
      expect(all.every((report) => report.reportedUser.id === userIdE)).toBe(true);
      expect(await reportsOf(`reportedUserId=${userIdD}`)).toHaveLength(0);

      await authed(superToken).get('/api/v1/admin/community/reports?reason=INCONNU').expect(400);
      await authed(superToken)
        .get('/api/v1/admin/community/reports?reportedUserId=pas-un-uuid')
        .expect(400);
    });
  });
});

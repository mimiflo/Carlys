process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
// Seuil minimal du schéma : le verrouillage se prouve en peu de requêtes.
process.env.AUTH_MAX_LOGIN_ATTEMPTS ??= '3';

import { type ApiErrorEnvelope } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Verrouillage de la connexion admin — suite ISOLÉE, exprès.
 *
 * La route porte un throttle strict de 10 requêtes / 60 s par adresse, et le
 * seau vit dans l'application : ce fichier ouvre la sienne pour que son
 * budget de connexions ne se partage avec aucune autre suite. Budget ici :
 * AUTH_MAX_LOGIN_ATTEMPTS échecs + 1 tentative bloquée + 1 connexion témoin,
 * soit N+2 requêtes — sous le seau de 10 tant que le seuil reste ≤ 8 (la CI
 * tourne à 3, donc 5 requêtes). Le scénario vivait dans admin.e2e-spec.ts et
 * portait cette suite à 9 connexions : un login de plus, ou un seuil injecté
 * par l'environnement, la faisait échouer en 429 sans rapport avec la route
 * testée.
 */
describe('Verrouillage de la connexion admin (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const lockedEmail = `e2e-lockout-verrou-${randomUUID()}@carlys.test`;
  const witnessEmail = `e2e-lockout-temoin-${randomUUID()}@carlys.test`;

  const errorOf = (body: unknown): ApiErrorEnvelope['error'] => (body as ApiErrorEnvelope).error;
  const login = (email: string, password: string) =>
    request(app.getHttpServer()).post('/api/v1/admin/auth/login').send({ email, password });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    // Le verrouillage n'exige aucun rôle : deux comptes nus suffisent.
    const passwordHash = await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id });
    await prisma.adminUser.createMany({
      data: [
        { email: lockedEmail, displayName: 'Admin verrouillé E2E', passwordHash },
        { email: witnessEmail, displayName: 'Admin témoin E2E', passwordHash },
      ],
    });
  });

  afterAll(async () => {
    await prisma.auditLog.deleteMany({
      where: { adminUser: { email: { in: [lockedEmail, witnessEmail] } } },
    });
    await prisma.adminUser.deleteMany({ where: { email: { in: [lockedEmail, witnessEmail] } } });
    // Le compteur de verrouillage vit dans Redis : on ne laisse pas de clé derrière soi.
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.del(`auth:lockout:admin:${lockedEmail}`, `auth:lockout:admin:${witnessEmail}`);
    await redis.quit();
    await prisma.$disconnect();
    await app.close();
  });

  it('après N échecs, la connexion admin est refusée (429) même avec le bon mot de passe', async () => {
    // Même politique que la connexion mobile (LockoutService), compteur distinct.
    const attempts = Number.parseInt(process.env.AUTH_MAX_LOGIN_ATTEMPTS ?? '5', 10);
    for (let failed = 0; failed < attempts; failed += 1) {
      await login(lockedEmail, 'MauvaisMotDePasse1!').expect(401);
    }

    const blocked = await login(lockedEmail, ADMIN_PASSWORD).expect(429);
    // Même code que la limitation de débit, et rien sur l'état du compte.
    expect(errorOf(blocked.body).code).toBe('RATE_LIMITED');
    expect(errorOf(blocked.body).message).not.toMatch(/verrouill|compte/i);

    // Le compteur est PROPRE au compte visé : les autres se connectent toujours.
    await login(witnessEmail, ADMIN_PASSWORD).expect(200);
  });
});

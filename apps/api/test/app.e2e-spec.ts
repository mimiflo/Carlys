process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiErrorEnvelope, type LivenessReport } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test, type TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';

describe('Carlys API (e2e) — fondation', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health/live répond 200 sans dépendre de PostgreSQL ni Redis', async () => {
    const response = await request(app.getHttpServer()).get('/health/live').expect(200);

    const body = response.body as LivenessReport;
    expect(body.status).toBe('ok');
    expect(typeof body.uptimeSeconds).toBe('number');
    expect(response.headers['x-request-id']).toBeDefined();
  });

  it('GET /metrics est accessible hors production', async () => {
    const response = await request(app.getHttpServer()).get('/metrics').expect(200);

    expect(response.text).toContain('carlys_api_');
  });

  it('propage un x-request-id fourni par le client', async () => {
    const response = await request(app.getHttpServer())
      .get('/health/live')
      .set('x-request-id', 'e2e-test-request-id')
      .expect(200);

    expect(response.headers['x-request-id']).toBe('e2e-test-request-id');
  });

  it('répond 404 avec une enveloppe d’erreur normalisée sur une route inconnue', async () => {
    const response = await request(app.getHttpServer()).get('/api/v1/inconnu').expect(404);

    const body = response.body as ApiErrorEnvelope;
    expect(body.error.code).toBe('NOT_FOUND');
    expect(typeof body.error.requestId).toBe('string');
    expect(Array.isArray(body.error.details)).toBe(true);
  });
});

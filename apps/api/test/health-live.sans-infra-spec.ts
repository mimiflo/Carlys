process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
// AUCUNE variable d'infrastructure n'est posée ici, et c'est TOUT l'enjeu de
// ce fichier : il doit passer sur une machine où ni PostgreSQL ni Redis ne
// tournent. Les autres suites e2e amorcent AppModule, dont le démarrage se
// connecte à Redis ; elles ne peuvent donc rien prouver sur ce point.

import { type LivenessReport } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { Test, type TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { type App } from 'supertest/types';
import { HealthController } from '../src/modules/health/health.controller';
import { HealthService } from '../src/modules/health/health.service';
import { DatabaseHealthProbe } from '../src/modules/health/probes/database.probe';
import { RedisHealthProbe } from '../src/modules/health/probes/redis.probe';

/**
 * La vivacité est la sonde que l'orchestrateur interroge pour décider s'il
 * doit REDÉMARRER le processus. Si elle consultait PostgreSQL ou Redis, une
 * panne de dépendance se transformerait en boucle de redémarrage de l'API :
 * le service tomberait ENTIÈREMENT pour une dépendance simplement dégradée.
 * C'est la raison d'être de la séparation live / ready, et ce fichier est ce
 * qui l'empêche de se perdre à la première refonte.
 */
class SondeQuiRefuse {
  constructor(readonly key: string) {}

  check(): never {
    throw new Error(
      `La vivacité a consulté la sonde « ${this.key} » : elle ne doit consulter AUCUNE dépendance.`,
    );
  }
}

describe('GET /health/live — sans la moindre infrastructure', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    // On n'amorce QUE le contrôleur de santé : pas d'AppModule, donc pas de
    // client Redis, pas de pool Prisma, pas de file d'attente. Les sondes
    // sont remplacées par des doublures qui LÈVENT si on les appelle : c'est
    // la garde qui compte. Une vivacité qui se mettrait à interroger Redis
    // ferait rougir ce test au lieu de passer inaperçue.
    const moduleFixture: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        HealthService,
        { provide: DatabaseHealthProbe, useValue: new SondeQuiRefuse('database') },
        { provide: RedisHealthProbe, useValue: new SondeQuiRefuse('redis') },
      ],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('répond 200 alors que ni PostgreSQL ni Redis ne sont joignables', async () => {
    const response = await request(app.getHttpServer()).get('/health/live').expect(200);

    const body = response.body as LivenessReport;
    expect(body.status).toBe('ok');
    expect(typeof body.uptimeSeconds).toBe('number');
    expect(body.uptimeSeconds).toBeGreaterThanOrEqual(0);
    expect(typeof body.timestamp).toBe('string');
  });

  it('reste honnête en rafale : dix appels, aucune sonde consultée', async () => {
    // Une doublure qui lève ferait échouer la requête (500) au premier appel
    // de sonde. Dix passages de suite : on vérifie qu'aucun chemin paresseux
    // (mise en cache, premier appel privilégié) ne consulte une dépendance.
    for (let i = 0; i < 10; i += 1) {
      await request(app.getHttpServer()).get('/health/live').expect(200);
    }
  });
});

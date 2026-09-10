process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { PresenceService } from '../src/infrastructure/presence/presence.service';
import { RedisThrottlerStorage } from '../src/infrastructure/throttling/redis-throttler.storage';

/**
 * Ce que l'orchestrateur lira sur le serveur.
 *
 * Ces mesures ne sont pas décoratives : ce sont les ENTRÉES de la mise à
 * l'échelle automatique. Une série absente ou mal nommée ne casse aucun test
 * métier — elle rend juste l'orchestrateur aveugle, en silence, jusqu'au jour
 * où il fallait qu'il voie. D'où une suite qui vérifie les NOMS autant que les
 * valeurs.
 */
describe('Observabilité (e2e)', () => {
  let app: INestApplication<App>;

  /** Extrait la valeur d'une série sans étiquette dans une exposition Prometheus. */
  const valeurDe = (expo: string, serie: string): number | undefined => {
    const ligne = expo.split('\n').find((l) => l.startsWith(`${serie} `));
    return ligne === undefined ? undefined : Number(ligne.slice(serie.length + 1));
  };

  beforeAll(async () => {
    const fixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = fixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('métriques HTTP', () => {
    it('compte une requête servie sous le MOTIF de sa route', async () => {
      await request(app.getHttpServer()).get('/health/live').expect(200);

      const expo = (await request(app.getHttpServer()).get('/metrics').expect(200)).text;

      expect(expo).toContain('carlys_api_http_requests_total');
      expect(expo).toMatch(
        /carlys_api_http_requests_total\{method="GET",route="\/health\/live",status="200"\}/,
      );
      expect(expo).toContain('carlys_api_http_request_duration_seconds_bucket');
    });

    it('range toutes les routes inconnues sous un libellé unique', async () => {
      // Deux chemins différents, dont un avec un identifiant : s'ils créaient
      // chacun leur série, un balayage d'URL ferait grandir la mémoire du
      // processus avec le trafic hostile.
      await request(app.getHttpServer()).get(`/inconnu-${randomUUID()}`).expect(404);
      await request(app.getHttpServer()).get(`/inconnu-${randomUUID()}`).expect(404);

      const expo = (await request(app.getHttpServer()).get('/metrics').expect(200)).text;
      const series404 = expo
        .split('\n')
        .filter(
          (l) => l.startsWith('carlys_api_http_requests_total{') && l.includes('status="404"'),
        );

      expect(series404).toHaveLength(1);
      expect(series404[0]).toContain('route="(inconnue)"');
    });

    it('compte AUSSI ce qu’un guard refuse — un intercepteur ne le verrait pas', async () => {
      // /api/v1/users/me sans jeton : le guard répond 401 avant tout
      // contrôleur. C'est exactement le code qu'on veut voir monter quand
      // quelque chose ne va pas.
      await request(app.getHttpServer()).get('/api/v1/users/me').expect(401);

      const expo = (await request(app.getHttpServer()).get('/metrics').expect(200)).text;

      expect(expo).toMatch(/carlys_api_http_requests_total\{[^}]*status="401"\}/);
    });

    it('rend la jauge des requêtes en vol à zéro une fois le calme revenu', async () => {
      await request(app.getHttpServer()).get('/health/live').expect(200);
      const expo = (await request(app.getHttpServer()).get('/metrics').expect(200)).text;

      // 1 = la requête /metrics elle-même, qui n'est pas encore terminée au
      // moment où le registre est rendu.
      expect(valeurDe(expo, 'carlys_api_http_requests_in_flight')).toBe(1);
    });
  });

  describe('utilisateurs en ligne', () => {
    it('publie la mesure, sa validité et sa fenêtre', async () => {
      const expo = (await request(app.getHttpServer()).get('/metrics').expect(200)).text;

      expect(valeurDe(expo, 'carlys_api_presence_up')).toBe(1);
      expect(valeurDe(expo, 'carlys_api_online_users_window_seconds')).toBe(300);
      expect(valeurDe(expo, 'carlys_api_online_users')).toBeGreaterThanOrEqual(0);
    });

    it('compte les personnes distinctes, pas les requêtes', async () => {
      const presence = app.get(PresenceService);
      const avant = await presence.onlineUsers();

      const utilisateur = randomUUID();
      await presence.touch(utilisateur);
      await presence.touch(utilisateur);
      await presence.touch(utilisateur);

      // Trois activités du MÊME utilisateur : +1, pas +3.
      expect(await presence.onlineUsers()).toBe(avant + 1);

      await presence.touch(randomUUID());
      expect(await presence.onlineUsers()).toBe(avant + 2);
    });

    it('est comptée dans Redis, donc commune à tous les réplicas', async () => {
      // Le point qui décide de tout : un second processus d'API doit voir les
      // utilisateurs enregistrés par le premier. On le simule avec une
      // seconde connexion Redis, indépendante de celle de l'application.
      const presence = app.get(PresenceService);
      const utilisateur = randomUUID();
      await presence.touch(utilisateur);

      const autreConnexion = new Redis(process.env.REDIS_URL as string);
      try {
        const minute = Math.floor(Date.now() / 60_000);
        const vuAilleurs = await autreConnexion.pfcount(`carlys:presence:m:${minute}`);
        expect(vuAilleurs).toBeGreaterThan(0);
      } finally {
        await autreConnexion.quit();
      }
    });
  });

  describe('limitation de débit partagée', () => {
    const limite = 3;
    const fenetreMs = 5_000;

    it('bloque au-delà de la limite et annonce un Retry-After en secondes', async () => {
      const storage = app.get(RedisThrottlerStorage);
      const cle = `e2e-${randomUUID()}`;

      for (let coup = 1; coup <= limite; coup += 1) {
        const verdict = await storage.increment(cle, fenetreMs, limite, fenetreMs, 'default');
        expect(verdict.totalHits).toBe(coup);
        expect(verdict.isBlocked).toBe(false);
        expect(verdict.timeToExpire).toBeGreaterThan(0);
      }

      const refus = await storage.increment(cle, fenetreMs, limite, fenetreMs, 'default');
      expect(refus.isBlocked).toBe(true);
      // Le guard pose cette valeur telle quelle dans Retry-After : des
      // millisecondes y annonceraient une réouverture dans 5 000 secondes.
      expect(refus.timeToBlockExpire).toBeGreaterThan(0);
      expect(refus.timeToBlockExpire).toBeLessThanOrEqual(Math.ceil(fenetreMs / 1_000));
    });

    it('ne repousse pas le déblocage quand le client insiste', async () => {
      const storage = app.get(RedisThrottlerStorage);
      const cle = `e2e-${randomUUID()}`;
      for (let coup = 0; coup <= limite; coup += 1) {
        await storage.increment(cle, fenetreMs, limite, fenetreMs, 'default');
      }

      const premierRefus = await storage.increment(cle, fenetreMs, limite, fenetreMs, 'default');
      await new Promise((resolve) => setTimeout(resolve, 1_100));
      const refusSuivant = await storage.increment(cle, fenetreMs, limite, fenetreMs, 'default');

      expect(refusSuivant.isBlocked).toBe(true);
      // Le compte à rebours DESCEND : marteler l'API ne doit pas réarmer le
      // blocage pour une fenêtre entière à chaque requête.
      expect(refusSuivant.timeToBlockExpire).toBeLessThan(premierRefus.timeToBlockExpire);
    });

    it('compte dans Redis : deux réplicas partagent le même quota', async () => {
      // Le mode de panne qu'on corrige ici. Avec le stockage par défaut, ce
      // second compteur repartirait de zéro et la limite réelle serait le
      // double de celle annoncée.
      const premier = app.get(RedisThrottlerStorage);
      const cle = `e2e-${randomUUID()}`;
      for (let coup = 0; coup < limite; coup += 1) {
        await premier.increment(cle, fenetreMs, limite, fenetreMs, 'default');
      }

      const secondReplica = await Test.createTestingModule({ imports: [AppModule] }).compile();
      const secondApp = secondReplica.createNestApplication<NestExpressApplication>();
      await secondApp.init();
      try {
        const verdict = await secondApp
          .get(RedisThrottlerStorage)
          .increment(cle, fenetreMs, limite, fenetreMs, 'default');

        expect(verdict.totalHits).toBe(limite + 1);
        expect(verdict.isBlocked).toBe(true);
      } finally {
        await secondApp.close();
      }
    });
  });
});

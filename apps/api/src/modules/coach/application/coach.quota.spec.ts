import { InternalServerErrorException, ServiceUnavailableException } from '@nestjs/common';
import { type Redis } from 'ioredis';
import { type AppConfigService } from '../../../config/app-config.service';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { CoachProviderUnavailableException } from '../domain/coach-model.port';
import { COACH_REFUNDS_PER_DAY, CoachQuota } from './coach.quota';

/** Panne du fournisseur dès le premier appel : rien n'a été consommé. */
const panneAVide = (raison = 'Coach : le fournisseur a répondu 429.') =>
  new CoachProviderUnavailableException(raison, {
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
  });

/**
 * Plafond quotidien du coach.
 *
 * Le coût est réel : ce compteur est la seule chose entre une boucle côté
 * client et une facture. Il s'incrémente AVANT l'appel au modèle, ce qui tient
 * le plafond même sous des envois simultanés ; un fournisseur tombé (503) AVANT
 * d'avoir rien consommé rend le message, trois fois par jour au plus.
 */
describe('CoachQuota', () => {
  const USER = 'user-1';

  function fakeRedis(): { redis: RedisService; store: Map<string, number>; expiries: string[] } {
    const store = new Map<string, number>();
    const expiries: string[] = [];
    const client = {
      incr: (key: string) => {
        const next = (store.get(key) ?? 0) + 1;
        store.set(key, next);
        return Promise.resolve(next);
      },
      expire: (key: string) => {
        expiries.push(key);
        return Promise.resolve(1);
      },
      decr: (key: string) => {
        const next = (store.get(key) ?? 0) - 1;
        store.set(key, next);
        return Promise.resolve(next);
      },
      get: (key: string) => Promise.resolve(store.get(key)?.toString() ?? null),
    } as unknown as Redis;
    return { redis: { getClient: () => client } as RedisService, store, expiries };
  }

  const config = (limit: number) => ({ coachDailyMessageLimit: limit }) as AppConfigService;

  it('décompte les messages et renvoie ce qu’il reste', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(3));

    await expect(quota.consume(USER)).resolves.toBe(2);
    await expect(quota.consume(USER)).resolves.toBe(1);
    await expect(quota.consume(USER)).resolves.toBe(0);
  });

  it('renvoie null une fois le plafond atteint', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));

    await expect(quota.consume(USER)).resolves.toBe(0);
    await expect(quota.consume(USER)).resolves.toBeNull();
    // Et il reste refusé : le compteur ne se relâche pas au tour suivant.
    await expect(quota.consume(USER)).resolves.toBeNull();
  });

  it('pose l’expiration une seule fois, à la première consommation', async () => {
    const { redis, expiries } = fakeRedis();
    const quota = new CoachQuota(redis, config(5));

    await quota.consume(USER);
    await quota.consume(USER);

    expect(expiries).toHaveLength(1);
  });

  it('sépare les utilisateurs et les jours', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));
    const lundi = new Date('2026-08-10T22:00:00.000Z');
    const mardi = new Date('2026-08-11T06:00:00.000Z');

    await expect(quota.consume(USER, lundi)).resolves.toBe(0);
    await expect(quota.consume(USER, lundi)).resolves.toBeNull();
    // Jour suivant : le compteur repart.
    await expect(quota.consume(USER, mardi)).resolves.toBe(0);
    // Autre utilisateur : compteur distinct.
    await expect(quota.consume('user-2', lundi)).resolves.toBe(0);
  });

  it('la clé est en UTC — les dates de Carlys le sont de bout en bout', () => {
    // 23 h à Paris en été, c'est encore le 10 en UTC : le plafond ne doit pas
    // se réinitialiser au milieu de la soirée d'un utilisateur.
    expect(CoachQuota.keyFor(USER, new Date('2026-08-10T21:00:00.000Z'))).toBe(
      `coach:quota:${USER}:2026-08-10`,
    );
  });

  it('lit ce qu’il reste sans rien consommer', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(4));

    await quota.consume(USER);
    await expect(quota.remaining(USER)).resolves.toBe(3);
    await expect(quota.remaining(USER)).resolves.toBe(3);
  });

  it('ne descend jamais sous zéro', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));

    await quota.consume(USER);
    await quota.consume(USER);

    await expect(quota.remaining(USER)).resolves.toBe(0);
  });

  it('un fournisseur tombé (503) dès le premier appel rend le message : rien n’a été consommé', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(3));
    const now = new Date('2026-09-27T10:00:00.000Z');
    const panne = panneAVide();

    await quota.consume(USER, now);
    // L'erreur repart telle quelle : le client voit toujours son 503.
    await expect(quota.refundIfUnavailable(USER, now, panne)).rejects.toBe(panne);

    await expect(quota.remaining(USER, now)).resolves.toBe(3);
  });

  it('un tour interrompu APRÈS un appel déjà servi garde le décompte : ses jetons sont partis', async () => {
    // Premier appel facturé (outils, historique), second en 429 : rendre le
    // message laisserait une seule personne vider le volume mensuel partagé.
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(3));
    const now = new Date('2026-09-27T10:00:00.000Z');
    const panne = new CoachProviderUnavailableException('Coach : le fournisseur a répondu 429.', {
      inputTokens: 9000,
      outputTokens: 1800,
      cacheReadTokens: 0,
    });

    await quota.consume(USER, now);
    await expect(quota.refundIfUnavailable(USER, now, panne)).rejects.toBe(panne);

    await expect(quota.remaining(USER, now)).resolves.toBe(2);
  });

  it(`au-delà de ${COACH_REFUNDS_PER_DAY} restitutions dans la journée, une panne garde le décompte`, async () => {
    // Sans borne, qui insiste pendant une panne (ou la provoque) appellerait
    // le fournisseur sans fin : trois appels par envoi, tous rendus.
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(10));
    const now = new Date('2026-09-27T10:00:00.000Z');

    for (let envoi = 0; envoi <= COACH_REFUNDS_PER_DAY; envoi++) {
      await quota.consume(USER, now);
      await expect(quota.refundIfUnavailable(USER, now, panneAVide())).rejects.toBeInstanceOf(
        CoachProviderUnavailableException,
      );
    }

    await expect(quota.remaining(USER, now)).resolves.toBe(9);
    // Le lendemain, le compteur de restitutions repart.
    const lendemain = new Date('2026-09-28T10:00:00.000Z');
    await quota.consume(USER, lendemain);
    await expect(quota.refundIfUnavailable(USER, lendemain, panneAVide())).rejects.toBeInstanceOf(
      CoachProviderUnavailableException,
    );
    await expect(quota.remaining(USER, lendemain)).resolves.toBe(10);
  });

  it('une panne de NOTRE code (500) garde le décompte : elle ne se rejoue pas gratuitement', async () => {
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(3));
    const now = new Date('2026-09-27T10:00:00.000Z');
    const bogue = new InternalServerErrorException();

    await quota.consume(USER, now);
    await expect(quota.refundIfUnavailable(USER, now, bogue)).rejects.toBe(bogue);

    await expect(quota.remaining(USER, now)).resolves.toBe(2);
  });

  it('course : un envoi refusé au plafond n’avale pas le message qu’une panne rend', async () => {
    // Plafond 1. A passe, B arrive en même temps et reçoit 429, puis le
    // fournisseur tombe pour A. Sans restitution du refus, le compteur de B
    // resterait compté : A serait rendu, et la personne resterait à 0 sans
    // avoir rien reçu.
    const { redis } = fakeRedis();
    const quota = new CoachQuota(redis, config(1));
    const now = new Date('2026-09-27T10:00:00.000Z');

    await expect(quota.consume(USER, now)).resolves.toBe(0);
    await expect(quota.consume(USER, now)).resolves.toBeNull();
    await expect(quota.refundIfUnavailable(USER, now, panneAVide())).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );

    await expect(quota.remaining(USER, now)).resolves.toBe(1);
  });

  it('le message se rend sur le jour où il a été compté, même si minuit passe entre-temps', async () => {
    const { redis, store } = fakeRedis();
    const quota = new CoachQuota(redis, config(3));
    const avantMinuit = new Date('2026-09-27T23:59:50.000Z');

    await quota.consume(USER, avantMinuit);
    await expect(quota.refundIfUnavailable(USER, avantMinuit, panneAVide())).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );

    expect(store.get(CoachQuota.keyFor(USER, avantMinuit))).toBe(0);
    // Aucune clé du lendemain créée à -1, sans expiration.
    expect(store.has(CoachQuota.keyFor(USER, new Date('2026-09-28T00:00:10.000Z')))).toBe(false);
  });
});

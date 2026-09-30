import { Redis } from 'ioredis';
import { type AppConfigService } from '../src/config/app-config.service';
import { type RedisService } from '../src/infrastructure/cache/redis.service';
import { CoachGate, GATE_LEASE_MS } from '../src/modules/coach/infrastructure/coach-gate';

/**
 * La file du coach contre un VRAI Redis : les scripts Lua ne se simulent pas.
 * Deux « exemplaires » de l'API partagent la même file — c'est tout l'enjeu.
 */
describe('CoachGate (Redis réel)', () => {
  let client: Redis;
  const settings = {
    maxConcurrent: 1,
    queueMaxSize: 2,
    maxConcurrentPerUser: 1,
    queueTimeoutMs: 120_000,
    requestTimeoutMs: 180_000,
  };
  const gate = () =>
    new CoachGate(
      { getClient: () => client } as unknown as RedisService,
      { coachGateway: settings } as unknown as AppConfigService,
    );

  beforeAll(() => {
    client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  });
  afterAll(async () => {
    await client.quit();
  });
  beforeEach(async () => {
    const keys = await client.keys('coach:gate:*');
    if (keys.length > 0) await client.del(...keys);
    Object.assign(settings, { maxConcurrent: 1, queueMaxSize: 2, maxConcurrentPerUser: 1 });
  });

  it('premier arrivé, premier servi — même entre deux exemplaires de l’API', async () => {
    const api1 = gate();
    const api2 = gate();
    expect(await api1.enter('r1', 'u1')).toBe('ok');
    expect(await api2.enter('r2', 'u2')).toBe('ok');

    // r2 demande avant r1 : il reste derrière, et le sait.
    expect(await api2.poll('r2')).toEqual({ acquired: false, ahead: 1 });
    expect(await api1.poll('r1')).toEqual({ acquired: true });
    expect(await api2.poll('r2')).toEqual({ acquired: false, ahead: 0 });

    await api1.leave('r1', 'u1');
    expect(await api2.poll('r2')).toEqual({ acquired: true });
    expect(await api2.snapshot()).toEqual({ active: 1, queued: 0 });
  });

  it('file pleine : refus immédiat, jamais une attente sans fin', async () => {
    const g = gate();
    // 1 créneau + 2 attentes = 3 places.
    for (const id of ['a', 'b', 'c']) expect(await g.enter(id, `user-${id}`)).toBe('ok');
    expect(await g.enter('d', 'user-d')).toBe('busy');
  });

  it('une personne, une génération à la fois (file comprise)', async () => {
    const g = gate();
    expect(await g.enter('m1', 'u1')).toBe('ok');
    expect(await g.enter('m2', 'u1')).toBe('user_busy');
    await g.leave('m1', 'u1');
    expect(await g.enter('m2', 'u1')).toBe('ok');
  });

  it('un exemplaire mort en plein tour : son bail expire et libère le créneau', async () => {
    const g = gate();
    const t0 = Date.now();
    await g.enter('mort', 'u1', t0);
    expect(await g.poll('mort', t0)).toEqual({ acquired: true });
    await g.enter('suivant', 'u2', t0);
    expect(await g.poll('suivant', t0)).toEqual({ acquired: false, ahead: 0 });

    // L'attente se manifeste (le vrai client le fait deux fois par seconde) ;
    // le bail de « mort », lui, n'est plus renouvelé.
    expect(await g.poll('suivant', t0 + 25_000)).toEqual({ acquired: false, ahead: 0 });
    expect(await g.poll('suivant', t0 + 50_000)).toEqual({ acquired: false, ahead: 0 });
    expect(await g.poll('suivant', t0 + GATE_LEASE_MS + 1)).toEqual({ acquired: true });
  });

  it('une attente muette (écran fermé) est retirée : elle ne bloque plus la file', async () => {
    const g = gate();
    const t0 = Date.now();
    await g.enter('actif', 'u1', t0);
    await g.poll('actif', t0);
    await g.enter('muette', 'u2', t0);
    await g.enter('vivante', 'u3', t0);
    expect(await g.poll('vivante', t0)).toEqual({ acquired: false, ahead: 1 });

    expect(await g.poll('vivante', t0 + 20_000)).toEqual({ acquired: false, ahead: 1 });
    await g.leave('actif', 'u1');
    // 31 s plus tard, « muette » ne s'est pas manifestée : partie.
    expect(await g.poll('vivante', t0 + 31_000)).toEqual({ acquired: true });
    expect(await g.poll('muette', t0 + 31_000)).toEqual({ lost: true });
  });

  it('le travail de fond ne passe JAMAIS devant une personne qui attend', async () => {
    const g = gate();
    settings.maxConcurrent = 2;
    await g.enter('p1', 'u1');
    await g.poll('p1');
    expect(await g.tryBackground('resume-1')).toBe(true);
    await g.leave('resume-1');

    await g.enter('p2', 'u2');
    await g.enter('p3', 'u3');
    // p2 prend le second créneau ; p3 attend : le fond ne passe pas.
    expect(await g.poll('p2')).toEqual({ acquired: true });
    await g.leave('p1', 'u1');
    expect(await g.tryBackground('resume-2')).toBe(false);
  });

  it('un exemplaire mort sans « leave » ne bloque pas la personne six minutes', async () => {
    const g = gate();
    const t0 = Date.now();
    await g.enter('orphelin', 'u1', t0);
    await g.poll('orphelin', t0);
    // L'exemplaire meurt : plus de bail renouvelé, ni de `leave`.
    // Une minute plus tard, le créneau s'est libéré seul…
    const later = t0 + GATE_LEASE_MS + 1;
    // … et la personne peut écrire de nouveau, sans attendre six minutes.
    expect(await g.enter('nouveau', 'u1', later)).toBe('ok');
  });
});

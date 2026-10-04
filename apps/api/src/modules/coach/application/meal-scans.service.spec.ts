import { ConflictException, NotFoundException } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { type FoodsService } from '../../nutrition/application/foods.service';
import {
  MealImageRejectedError,
  type MealVisionClient,
  type SeenFood,
} from '../infrastructure/meal-vision.client';
import { type CoachAvailability } from './coach.availability';
import { type CoachGateway } from './coach-gateway';
import { MealScansService } from './meal-scans.service';
import { type CoachMetrics } from '../infrastructure/coach-metrics';

const PHOTO = readFileSync(
  join(__dirname, '..', '..', '..', '..', 'test', 'fixtures', 'jpeg', 'repas-exif-gps.jpg'),
);
const upload = { mimeType: 'image/jpeg', content: PHOTO };
const SCAN = '0f8fad5b-d9cb-469f-a165-70867728950e';

describe('MealScansService', () => {
  function setup(see: () => Promise<SeenFood[]>, scansPerDay = 10, raceOn?: string) {
    const store = new Map<string, string>();
    const counters = new Map<string, number>();
    const redis = {
      getClient: () => ({
        get: (key: string) => Promise.resolve(store.get(key) ?? null),
        set: (key: string, value: string, ...args: unknown[]) => {
          if (args.includes('NX') && (store.has(key) || raceOn === key)) {
            if (raceOn === key) store.set(key, value);
            return Promise.resolve(null);
          }
          store.set(key, value);
          return Promise.resolve('OK');
        },
        incr: (key: string) => {
          counters.set(key, (counters.get(key) ?? 0) + 1);
          return Promise.resolve(counters.get(key));
        },
        decr: (key: string) => {
          counters.set(key, (counters.get(key) ?? 0) - 1);
          return Promise.resolve(counters.get(key));
        },
        expire: () => Promise.resolve(1),
        del: (key: string) => Promise.resolve(store.delete(key) ? 1 : 0),
      }),
    };
    const vision = { see: jest.fn(see) };
    // Le travail ouvert, comme la supervision le lit avant de retirer un exemplaire.
    const workOpen = {
      value: 0,
      inc: () => (workOpen.value += 1),
      dec: () => (workOpen.value -= 1),
    };
    const service = new MealScansService(
      {
        assertVisionAvailable: () => Promise.resolve('qwen3-vl:4b-instruct'),
      } as unknown as CoachAvailability,
      {
        withSlot: (_u: string, _s: AbortSignal, task: () => Promise<unknown>) => task(),
      } as unknown as CoachGateway,
      vision as unknown as MealVisionClient,
      {
        closest: (label: string) =>
          Promise.resolve(
            label.startsWith('Poulet')
              ? {
                  code: 1,
                  name: 'Poulet, filet, cuit',
                  shortName: 'Poulet',
                  group: null,
                  per100g: { kcal: 120, proteinG: 25, carbsG: 0, fatG: 2 },
                }
              : null,
          ),
        source: () =>
          Promise.resolve({ attribution: 'Ciqual', license: 'Etalab', url: 'u', version: '2020' }),
      } as unknown as FoodsService,
      redis as unknown as RedisService,
      {
        coachGateway: {
          queueTimeoutMs: 1_000,
          mealScansPerDay: scansPerDay,
        },
      } as unknown as AppConfigService,
      { workOpen } as unknown as CoachMetrics,
      { info: jest.fn(), warn: jest.fn(), error: jest.fn() } as unknown as PinoLogger,
    );
    return { service, vision, counters, store, workOpen };
  }

  const settle = () => new Promise((resolve) => setImmediate(resolve));

  it('en cours, puis les aliments vus, rapprochés de la base', async () => {
    const { service, workOpen } = setup(() =>
      Promise.resolve([
        { name: 'Poulet, filet, grillé', grams: 150 },
        { name: 'Sauce mystère', grams: 30 },
      ]),
    );
    const started = await service.start('u1', SCAN, upload);
    expect(started.scan.status).toBe('PENDING');
    await settle();
    const done = await service.read('u1', SCAN);
    expect(done.scan.status).toBe('DONE');
    expect(workOpen.value).toBe(0);
    expect(done.scan.items.map((item) => [item.seen, item.grams, item.food?.code ?? null])).toEqual(
      [
        ['Poulet, filet, grillé', 150, 1],
        ['Sauce mystère', 30, null],
      ],
    );
  });

  it('rejoué, le même scan : ni seconde analyse, ni tour de quota', async () => {
    const { service, vision, counters } = setup(() => Promise.resolve([]));
    await service.start('u1', SCAN, upload);
    await settle();
    await service.start('u1', SCAN, upload);
    expect(vision.see).toHaveBeenCalledTimes(1);
    expect([...counters.values()]).toEqual([1]);
  });

  it('au-delà du quota du jour : 429, et le compteur ne dérive pas', async () => {
    const { service, counters } = setup(() => Promise.resolve([]), 1);
    await service.start('u1', SCAN, upload);
    await expect(
      service.start('u1', '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed', upload),
    ).rejects.toThrow('scans d’assiette du jour');
    expect([...counters.values()]).toEqual([1]);
  });

  it('une analyse qui échoue : FAILED, dit à la personne, et rendue au quota', async () => {
    const { service, counters } = setup(() => Promise.reject(new Error('worker tombé')));
    await service.start('u1', SCAN, upload);
    await settle();
    const failed = await service.read('u1', SCAN);
    expect(failed.scan.status).toBe('FAILED');
    expect(failed.scan.error).toContain('saisis le repas à la main');
    expect([...counters.values()]).toEqual([0]);
  });

  it('le travail reste ouvert jusqu’au résultat écrit, même en échec', async () => {
    // Le scan tourne sans requête ouverte : sans cette jauge, la supervision
    // retirait l'exemplaire en pleine analyse.
    let finish: (error: Error) => void = () => undefined;
    const { service, workOpen } = setup(() => new Promise((_resolve, reject) => (finish = reject)));
    await service.start('u1', SCAN, upload);
    await settle();
    expect(workOpen.value).toBe(1);
    finish(new Error('worker tombé'));
    await settle();
    expect((await service.read('u1', SCAN)).scan.status).toBe('FAILED');
    expect(workOpen.value).toBe(0);
  });

  it('deux envois simultanés du même scan : un seul tour de quota', async () => {
    const { service, vision, counters } = setup(
      () => Promise.resolve([]),
      10,
      `coach:meal-scan:${SCAN}`,
    );
    const raced = await service.start('u1', SCAN, upload);
    expect(raced.scan.status).toBe('PENDING');
    expect(vision.see).not.toHaveBeenCalled();
    expect([...counters.values()]).toEqual([]);
  });

  it('resté en cours au-delà de son échéance (API relancée) : FAILED', async () => {
    const { service, counters } = setup(() => new Promise<SeenFood[]>(() => undefined));
    await service.start('u1', SCAN, upload);
    const now = Date.now();
    const clock = jest.spyOn(Date, 'now').mockReturnValue(now + 600_000);
    try {
      const lost = await service.read('u1', SCAN);
      expect(lost.scan.status).toBe('FAILED');
      expect(lost.scan.error).toContain('saisis le repas à la main');
      // Rendu au quota UNE fois, quel que soit le nombre de relectures.
      await service.read('u1', SCAN);
      expect([...counters.values()]).toEqual([0]);
    } finally {
      clock.mockRestore();
    }
  });

  it('une image que le modèle refuse (4xx) reste comptée', async () => {
    const { service, counters } = setup(() =>
      Promise.reject(new MealImageRejectedError('Modèle de vision : 400')),
    );
    await service.start('u1', SCAN, upload);
    await settle();
    expect((await service.read('u1', SCAN)).scan.status).toBe('FAILED');
    expect([...counters.values()]).toEqual([1]);
  });

  it('un JPEG que le modèle ne lirait pas (arithmétique, 12 bits, géant) : 415', async () => {
    const { service, vision } = setup(() => Promise.resolve([]));
    const frame = PHOTO.indexOf(Buffer.from([0xff, 0xc0]));
    const variants = [
      (b: Buffer) => b.writeUInt8(0xc9, frame + 1),
      (b: Buffer) => b.writeUInt8(12, frame + 4),
      (b: Buffer) => b.writeUInt16BE(65_000, frame + 7),
    ];
    for (const alter of variants) {
      const content = Buffer.from(PHOTO);
      alter(content);
      await expect(service.start('u1', SCAN, { mimeType: 'image/jpeg', content })).rejects.toThrow(
        '4 096 px au plus',
      );
    }
    expect(vision.see).not.toHaveBeenCalled();
  });

  it('le scan d’autrui ne se lit pas, et son identifiant ne se rejoue pas', async () => {
    const { service } = setup(() => Promise.resolve([]));
    await service.start('u1', SCAN, upload);
    await expect(service.read('u2', SCAN)).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.start('u2', SCAN, upload)).rejects.toBeInstanceOf(ConflictException);
  });

  it('une photo qui n’est pas un JPEG ne part pas au modèle', async () => {
    const { service, vision } = setup(() => Promise.resolve([]));
    await expect(
      service.start('u1', SCAN, { mimeType: 'image/png', content: Buffer.from('png') }),
    ).rejects.toThrow('JPEG');
    expect(vision.see).not.toHaveBeenCalled();
  });
});

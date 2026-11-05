import { HttpException, ServiceUnavailableException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { ProductNotFoundException } from '../../../common/filters/product-not-found.exception';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import {
  OpenFoodFactsUnavailable,
  OpenFoodFactsUnreadable,
} from '../infrastructure/open-food-facts.client';
import { ProductsService } from './products.service';

/** Un EAN-13 valide de plus pour chaque [n] : des codes jamais vus. */
function ean(n: number): string {
  const base = `200${String(n).padStart(9, '0')}`;
  let sum = 0;
  for (let i = base.length - 1, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += Number(base[i]) * weight;
  }
  return `${base}${(10 - (sum % 10)) % 10}`;
}

/** Un Redis qui COMPTE vraiment : `multi().incr().expire().exec()` compris. */
function fakeRedis(store = new Map<string, string>()) {
  const bump = (key: string): number => {
    const next = Number(store.get(key) ?? 0) + 1;
    store.set(key, String(next));
    return next;
  };
  const client = {
    get: (key: string) => Promise.resolve(store.get(key) ?? null),
    set: (key: string, value: string) => {
      store.set(key, value);
      return Promise.resolve('OK');
    },
    exists: (key: string) => Promise.resolve(store.has(key) ? 1 : 0),
    multi: () => {
      const replies: [null, number][] = [];
      const chain = {
        incr: (key: string) => {
          replies.push([null, bump(key)]);
          return chain;
        },
        expire: () => {
          replies.push([null, 1]);
          return chain;
        },
        exec: () => Promise.resolve(replies),
      };
      return chain;
    },
  };
  return { getClient: () => client } as unknown as RedisService;
}

describe('ProductsService', () => {
  const code = '3017620422003';
  const fiche = { product_name: 'Pâte à tartiner', nutriments: { 'energy-kcal_100g': 539 } };
  const PAUSE = 'nutrition:product:pause';

  // Les compteurs sont par minute : l'horloge ne doit pas en changer en plein test.
  beforeEach(() => jest.spyOn(Date, 'now').mockReturnValue(Date.UTC(2026, 10, 4, 10, 0, 30)));
  afterEach(() => jest.restoreAllMocks());

  function setup(
    product: (barcode: string) => Promise<unknown>,
    store = new Map<string, string>(),
  ) {
    const client = { product: jest.fn(product) };
    const service = new ProductsService(client, fakeRedis(store), {
      warn: jest.fn(),
    } as unknown as PinoLogger);
    return { service, client, store };
  }

  it('lit la base une fois, puis le cache', async () => {
    const { service, client } = setup(() => Promise.resolve(fiche));
    const first = await service.byBarcode(code, 'u1');
    const second = await service.byBarcode(code, 'u1');
    expect(first.product.name).toBe('Pâte à tartiner');
    expect(second).toEqual(first);
    expect(first.source.attribution).toBe('Source : Open Food Facts');
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  it('un code inconnu se garde aussi : 404 dédié, sans redemander', async () => {
    const { service, client } = setup(() => Promise.resolve(null));
    await expect(service.byBarcode(code, 'u1')).rejects.toBeInstanceOf(ProductNotFoundException);
    await expect(service.byBarcode(code, 'u1')).rejects.toBeInstanceOf(ProductNotFoundException);
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  it('UPC-A et EAN-13 commençant par 0 : une seule clé, une seule lecture', async () => {
    const { service, client } = setup(() => Promise.resolve(fiche));
    await service.byBarcode('036000291452', 'u1');
    await service.byBarcode('0036000291452', 'u1');
    expect(client.product).toHaveBeenCalledTimes(1);
    expect(client.product).toHaveBeenCalledWith('0036000291452');
  });

  describe('la base saturée ou en panne', () => {
    it('429 ou 503 : 503 pour la personne, rien en cache, et une pause', async () => {
      const { service, store, client } = setup(() =>
        Promise.reject(new OpenFoodFactsUnavailable('429', true)),
      );
      await expect(service.byBarcode(code, 'u1')).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
      expect(store.has(PAUSE)).toBe(true);
      expect(store.has(`nutrition:product:v1:${code}`)).toBe(false);
      await expect(service.byBarcode(code, 'u1')).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
      expect(client.product).toHaveBeenCalledTimes(1);
    });

    it('un délai dépassé isolé échoue seul : pas de pause', async () => {
      let calls = 0;
      const { service, store } = setup(() =>
        ++calls === 1 ? Promise.reject(new Error('timeout')) : Promise.resolve(fiche),
      );
      await expect(service.byBarcode(code, 'u1')).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
      expect(store.has(PAUSE)).toBe(false);
      expect((await service.byBarcode(code, 'u1')).product.name).toBe('Pâte à tartiner');
    });

    it('des échecs répétés dans la minute ouvrent la pause', async () => {
      const { service, store } = setup(() => Promise.reject(new Error('réseau')));
      for (const n of [1, 2, 3]) {
        await expect(service.byBarcode(ean(n), 'u1')).rejects.toBeInstanceOf(
          ServiceUnavailableException,
        );
      }
      expect(store.has(PAUSE)).toBe(true);
    });
  });

  it('une fiche inexploitable vaut « inconnu » un jour, sans pause pour les autres', async () => {
    const { service, store, client } = setup(() =>
      Promise.reject(new OpenFoodFactsUnreadable('trop lourde')),
    );
    await expect(service.byBarcode(code, 'u1')).rejects.toBeInstanceOf(ProductNotFoundException);
    expect(store.get(`nutrition:product:v1:${code}`)).toBe('0');
    expect(store.has(PAUSE)).toBe(false);
    await expect(service.byBarcode(code, 'u2')).rejects.toBeInstanceOf(ProductNotFoundException);
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  describe('les plafonds de lecture chez Open Food Facts', () => {
    it('10 codes jamais vus par personne et par minute ; les autres passent', async () => {
      const { service, client } = setup(() => Promise.resolve(fiche));
      for (let n = 0; n < 10; n++) await service.byBarcode(ean(n), 'avide');
      const refused = service.byBarcode(ean(10), 'avide');
      await expect(refused).rejects.toBeInstanceOf(HttpException);
      await expect(refused).rejects.toMatchObject({ status: 429 });
      expect(client.product).toHaveBeenCalledTimes(10);
      await expect(service.byBarcode(ean(11), 'voisin')).resolves.toBeDefined();
    });

    it('un produit en cache ne compte pas dans le budget', async () => {
      const { service, client } = setup(() => Promise.resolve(fiche));
      for (let n = 0; n < 20; n++) await service.byBarcode(code, 'fidèle');
      expect(client.product).toHaveBeenCalledTimes(1);
    });

    it('au-delà de 80 lectures par minute, tous comptes confondus : très sollicité', async () => {
      const { service, client } = setup(() => Promise.resolve(fiche));
      for (let n = 0; n < 80; n++) await service.byBarcode(ean(n), `u${Math.floor(n / 10)}`);
      const busy = service.byBarcode(ean(80), 'nouveau');
      await expect(busy).rejects.toBeInstanceOf(UserFacingUnavailableException);
      await expect(busy).rejects.toMatchObject({ code: 'SERVICE_BUSY' });
      expect(client.product).toHaveBeenCalledTimes(80);
    });
  });

  it('une fiche abîmée ou d’une autre forme en cache se relit à la source', async () => {
    for (const abimee of ['{abîmé', JSON.stringify({ name: 1 })]) {
      const store = new Map([[`nutrition:product:v1:${code}`, abimee]]);
      const { service, client } = setup(() => Promise.resolve(fiche), store);
      expect((await service.byBarcode(code, 'u1')).product.name).toBe('Pâte à tartiner');
      expect(client.product).toHaveBeenCalledTimes(1);
    }
  });

  it('un code illisible ne sort pas de l’API', async () => {
    const { service, client } = setup(() => Promise.resolve(fiche));
    await expect(service.byBarcode('3017620422004', 'u1')).rejects.toThrow('Code-barres illisible');
    expect(client.product).not.toHaveBeenCalled();
  });
});

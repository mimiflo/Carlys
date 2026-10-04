import { NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { ProductsService } from './products.service';

describe('ProductsService', () => {
  const code = '3017620422003';
  const fiche = { product_name: 'Pâte à tartiner', nutriments: { 'energy-kcal_100g': 539 } };

  function setup(product: () => Promise<unknown>, store = new Map<string, string>()) {
    const client = { product: jest.fn(product) };
    const redis = {
      getClient: () => ({
        get: (key: string) => Promise.resolve(store.get(key) ?? null),
        set: (key: string, value: string) => {
          store.set(key, value);
          return Promise.resolve('OK');
        },
        exists: (key: string) => Promise.resolve(store.has(key) ? 1 : 0),
        incr: () => Promise.resolve(1),
        expire: () => Promise.resolve(1),
      }),
    };
    const service = new ProductsService(
      client,
      redis as unknown as RedisService,
      { warn: jest.fn() } as unknown as PinoLogger,
    );
    return { service, client, store };
  }

  it('lit la base une fois, puis le cache', async () => {
    const { service, client } = setup(() => Promise.resolve(fiche));
    const first = await service.byBarcode(code);
    const second = await service.byBarcode(code);
    expect(first.product.name).toBe('Pâte à tartiner');
    expect(second).toEqual(first);
    expect(first.source.attribution).toBe('Source : Open Food Facts');
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  it('un code inconnu se garde aussi : 404, sans redemander', async () => {
    const { service, client } = setup(() => Promise.resolve(null));
    await expect(service.byBarcode(code)).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.byBarcode(code)).rejects.toBeInstanceOf(NotFoundException);
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  it('la base qui ne répond pas : 503, rien en cache, et une pause avant de la rappeler', async () => {
    const { service, store, client } = setup(() => Promise.reject(new Error('timeout')));
    await expect(service.byBarcode(code)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect([...store.keys()]).toEqual(['nutrition:product:pause']);
    await expect(service.byBarcode(code)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  it('une fiche abîmée en cache se relit à la source', async () => {
    const store = new Map([[`nutrition:product:v1:${code}`, '{abîmé']]);
    const { service, client } = setup(() => Promise.resolve(fiche), store);
    expect((await service.byBarcode(code)).product.name).toBe('Pâte à tartiner');
    expect(client.product).toHaveBeenCalledTimes(1);
  });

  it('un code illisible ne sort pas de l’API', async () => {
    const { service, client } = setup(() => Promise.resolve(fiche));
    await expect(service.byBarcode('3017620422004')).rejects.toThrow('Code-barres illisible');
    expect(client.product).not.toHaveBeenCalled();
  });
});

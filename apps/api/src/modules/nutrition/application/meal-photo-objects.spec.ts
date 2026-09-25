import { ServiceUnavailableException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { InMemoryObjectStore } from '../../../../test/support/in-memory-object-store';
import { MealPhotoObjects } from './meal-photo-objects';

const USER = '0f6b1b5e-2a44-4c3e-9d6f-111111111111';

function build(store = new InMemoryObjectStore()) {
  const logger = { error: jest.fn(), info: jest.fn() };
  const objects = new MealPhotoObjects(store, logger as unknown as PinoLogger);
  return { store, logger, objects };
}

describe('MealPhotoObjects', () => {
  it('dépose sous une clé NEUVE et non devinable, dans le préfixe de la personne', async () => {
    const { store, objects } = build();

    const first = await objects.save(USER, Buffer.from('a'), 'req-1');
    const second = await objects.save(USER, Buffer.from('a'), 'req-2');

    expect(first).toMatch(
      new RegExp(
        `^meal-photos/${USER}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}\\.jpg$`,
      ),
    );
    expect(second).not.toBe(first);
    expect(store.objects.get(first)?.contentType).toBe('image/jpeg');
  });

  it('un stockage qui refuse le dépôt : 503 et une erreur journalisée avec le requestId', async () => {
    const store = new InMemoryObjectStore();
    store.put = () => Promise.reject(new Error('panne'));
    const { objects, logger } = build(store);

    await expect(objects.save(USER, Buffer.from('a'), 'req-9')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-9' }),
      expect.any(String),
    );
  });

  it('un effacement qui échoue est JOURNALISÉ en erreur, avec le requestId, et jamais levé', async () => {
    const { store, objects, logger } = build();
    const key = await objects.save(USER, Buffer.from('a'), 'req-1');
    store.failDeletes = true;

    await expect(objects.discard(key, 'req-2')).resolves.toBeUndefined();

    expect(store.objects.has(key)).toBe(true);
    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-2', storageKey: key }),
      expect.stringContaining('meal-photos-sweep'),
    );
  });

  it('effacer tout le compte vide SON préfixe, orphelins compris, et rien d’autre', async () => {
    const { store, objects } = build();
    store.pageSize = 2; // la pagination est éprouvée, pas supposée
    for (let index = 0; index < 5; index += 1) {
      await objects.save(USER, Buffer.from('a'), 'req');
    }
    await store.put(`meal-photos/${USER}/orphelin-sans-ligne.jpg`, Buffer.from('b'), 'image/jpeg');
    const other = await objects.save('autre-personne', Buffer.from('c'), 'req');

    await objects.discardAllOf(USER, 'req-3');

    expect(store.keysUnder(`meal-photos/${USER}/`)).toEqual([]);
    expect(store.objects.has(other)).toBe(true);
  });

  it('effacer tout le compte quand le stockage ne répond pas : journalisé, jamais levé', async () => {
    const { store, objects, logger } = build();
    await objects.save(USER, Buffer.from('a'), 'req');
    store.failDeletes = true;

    await expect(objects.discardAllOf(USER, 'req-4')).resolves.toBeUndefined();

    expect(logger.error).toHaveBeenCalledWith(
      expect.objectContaining({ requestId: 'req-4', userId: USER }),
      expect.stringContaining('NON effacées'),
    );
  });
});

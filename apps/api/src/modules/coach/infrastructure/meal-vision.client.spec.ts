import { type AppConfigService } from '../../../config/app-config.service';
import { type CoachWorkerPool } from './coach-worker-pool';
import { MealImageRejectedError, MealVisionClient, parseSeenFoods } from './meal-vision.client';

describe('parseSeenFoods', () => {
  it('lit la liste du modèle : nom et grammes', () => {
    expect(
      parseSeenFoods(
        '{"aliments":[{"nom":"Poulet, filet, grillé","grammes":150},{"nom":"Riz blanc, cuit","grammes":120.4}]}',
      ),
    ).toEqual([
      { name: 'Poulet, filet, grillé', grams: 150 },
      { name: 'Riz blanc, cuit', grams: 120 },
    ]);
  });

  it('ne croit pas le modèle : noms vides, grammes hors bornes, caractères invisibles', () => {
    expect(
      parseSeenFoods(
        JSON.stringify({
          aliments: [
            { nom: '  ', grammes: 50 },
            { nom: 'Pain', grammes: 0 },
            { nom: 'Gâteau', grammes: 9000 },
            { nom: 'Pomme‮​', grammes: 120 },
            'pas un objet',
          ],
        }),
      ),
    ).toEqual([{ name: 'Pomme', grams: 120 }]);
  });

  it('une réponse illisible ou sans liste : rien de vu', () => {
    expect(parseSeenFoods('pas du JSON')).toEqual([]);
    expect(parseSeenFoods('{"autre":1}')).toEqual([]);
    expect(parseSeenFoods(undefined)).toEqual([]);
  });

  it('huit aliments au plus', () => {
    const many = Array.from({ length: 12 }, (_, i) => ({ nom: `Aliment ${i}`, grammes: 10 }));
    expect(parseSeenFoods(JSON.stringify({ aliments: many }))).toHaveLength(8);
  });

  describe('le worker', () => {
    function client() {
      const worker = { url: 'http://vision.test/v1' };
      const pool = { acquire: jest.fn(() => worker), release: jest.fn() };
      const vision = new MealVisionClient(
        {
          coachProvider: {},
        } as unknown as AppConfigService,
        pool as unknown as CoachWorkerPool,
      );
      return { vision, pool, worker };
    }

    afterEach(() => jest.restoreAllMocks());

    it('une image refusée (4xx) : le worker reste en service', async () => {
      jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{}', { status: 400 }));
      const { vision, pool, worker } = client();
      await expect(
        vision.see('m', Buffer.from('x'), new AbortController().signal),
      ).rejects.toBeInstanceOf(MealImageRejectedError);
      expect(pool.release).toHaveBeenCalledWith(worker, false);
    });

    it('une panne (5xx) : le worker est écarté', async () => {
      jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{}', { status: 500 }));
      const { vision, pool, worker } = client();
      await expect(vision.see('m', Buffer.from('x'), new AbortController().signal)).rejects.toThrow(
        '500',
      );
      expect(pool.release).toHaveBeenCalledWith(worker, true);
    });
  });
});

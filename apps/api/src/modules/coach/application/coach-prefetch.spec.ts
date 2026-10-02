import { prefetchFor } from './coach-prefetch';

const names = (request: string) => prefetchFor(request).map((call) => call.name);

/**
 * Ses données lues AVANT que le modèle n'écrive : constaté le 1er octobre
 * 2026, « Tu as déjà des records de soulevé de terre » sans en avoir lu un.
 */
describe('prefetchFor', () => {
  it('une question sur SES données lit ce qu’elle demande', () => {
    expect(names('Quel est mon record au squat ?')).toEqual(['get_personal_records']);
    expect(names('Est-ce que je progresse ?')).toEqual(['get_progress_overview']);
    expect(names('Mon évolution ce mois-ci ?')).toEqual(['get_progress_overview']);
    expect(names('J’ai maigri ?')).toEqual(['get_body_weight_trend']);
    expect(names('Combien de protéines je dois manger ?')).toEqual([
      'get_nutrition_targets',
      'get_recent_meals',
    ]);
    // « Par où je commence ? » : ce qu'il a déjà fait, avant de conseiller.
    expect(names('Par où je commence ?')).toEqual(['get_recent_sessions']);
    expect(names('Tu peux regarder mes dernières séances ?')).toEqual(['get_recent_sessions']);
  });

  it('plusieurs sujets, plusieurs lectures, chacune une fois', () => {
    const calls = prefetchFor('Mes records et ma régularité, est-ce que je progresse ?');
    expect(calls.map((call) => call.name)).toEqual([
      'get_personal_records',
      'get_progress_overview',
    ]);
    expect(new Set(calls.map((call) => call.id)).size).toBe(calls.length);
  });

  it('une question qui ne parle pas de ses données ne lit rien', () => {
    for (const request of [
      'Explique-moi la surcharge progressive',
      'Comment bien faire un soulevé de terre ?',
      'Merci beaucoup !',
      'C’est quoi un bon échauffement ?',
    ]) {
      expect(names(request)).toEqual([]);
    }
  });
});

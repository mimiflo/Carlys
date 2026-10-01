import { announcesAction } from './announced-action';

/**
 * Un petit modèle annonce parfois une recherche et rend la main sans la
 * faire : la personne attend une suite qui ne vient jamais. Les phrases
 * ci-dessous sont celles constatées le 1er octobre 2026 (Qwen3-4B).
 */
describe('announcesAction', () => {
  it('reconnaît une fin qui promet une suite', () => {
    expect(
      announcesAction(
        'Je cherche des exercices pour les pecs. C’est un groupe musculaire clair. ' +
          'J’essaie de les trouver dans le catalogue. Une minute.',
      ),
    ).toBe(true);
    expect(
      announcesAction(
        'Améliorer les pectoraux, c’est bien. Vérifions d’abord ce que tu as déjà enregistré récemment.',
      ),
    ).toBe(true);
    expect(
      announcesAction('D’abord, je vérifie les modèles de séance que tu as déjà choisis.'),
    ).toBe(true);
    expect(announcesAction('Je vais chercher les exercices adaptés, un instant…')).toBe(true);
    expect(announcesAction('Voici ce que je te propose :')).toBe(true);
  });

  it('laisse passer une vraie réponse, même quand elle parle d’avenir', () => {
    expect(
      announcesAction(
        'Garde tes trois séries de 8 à 70 kg cette semaine. Si elles passent proprement, monte à 72,5 kg.',
      ),
    ).toBe(false);
    expect(
      announcesAction(
        'Je vais te laisser essayer ça cette semaine, dis-moi comment ça s’est passé.',
      ),
    ).toBe(false);
    expect(announcesAction('')).toBe(false);
    // Relecture : des fins de réponse ordinaires, qui ne promettent rien.
    for (const ordinary of [
      'Attends-toi à des courbatures.',
      'D’abord, échauffe-toi 10 minutes.',
      'Un moment de repos de 2 min suffit.',
      'Laisse-moi savoir comment ça se passe !',
      'Je regarde ça avec toi la semaine prochaine.',
      'Un instant de pause entre les séries suffit.',
    ]) {
      expect(announcesAction(ordinary)).toBe(false);
    }
  });
});

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
    // Débuter : ses séances, et son profil — il attend un plan.
    expect(names('Par où je commence ?')).toEqual(['get_recent_sessions', 'get_training_profile']);
    expect(names('Tu peux regarder mes dernières séances ?')).toEqual(['get_recent_sessions']);
  });

  it('lue sans accents : au téléphone, on les oublie souvent', () => {
    expect(names('mes dernieres seances ?')).toEqual(['get_recent_sessions']);
    expect(names('combien de proteines je dois manger')).toContain('get_nutrition_targets');
    expect(names('mon evolution ce mois')).toEqual(['get_progress_overview']);
  });

  it('des identifiants de neuf caractères alphanumériques, comme Mistral les exige', () => {
    for (const call of prefetchFor('Mes records, mon poids et mes calories ?')) {
      expect(call.id).toMatch(/^[a-zA-Z0-9]{9}$/);
    }
  });

  it('plusieurs sujets, plusieurs lectures, chacune une fois', () => {
    const calls = prefetchFor('Mes records et ma régularité, est-ce que je progresse ?');
    expect(calls.map((call) => call.name)).toEqual([
      'get_personal_records',
      'get_progress_overview',
    ]);
    expect(new Set(calls.map((call) => call.id)).size).toBe(calls.length);
  });

  it('une séance ou un programme demandé : son profil, qu’il relit toujours avant de proposer', () => {
    expect(names('Une séance full body rapide au poids du corps ?')).toEqual([
      'get_training_profile',
    ]);
    expect(names('Prépare-moi une séance haut du corps pour ce soir')).toEqual([
      'get_training_profile',
    ]);
    expect(names('Je veux un programme de 4 semaines')).toEqual(['get_training_profile']);
    // Parler de SA séance n'en demande pas une.
    expect(names('Mon programme me fatigue, normal ?')).not.toContain('get_training_profile');
  });

  it('une séance pour des muscles NOMMÉS : leurs exercices, lus d’avance', () => {
    // Constaté le 2 octobre 2026 : « je dois faire une séance quad fessiers »
    // n'était pas reconnue ; le modèle ne cherchait que « fessiers », et la
    // séance arrivait en texte, sans carte, faite de ponts fessiers.
    const calls = prefetchFor('je dois faire une séance quad fessiers que me conseilles tu?');
    expect(calls.map((call) => [call.name, call.input])).toEqual([
      ['get_training_profile', {}],
      ['search_exercises', { muscleGroupSlug: 'quadriceps' }],
      ['search_exercises', { muscleGroupSlug: 'fessiers' }],
    ]);
    expect(new Set(calls.map((call) => call.id)).size).toBe(calls.length);
    // Les jambes : leurs trois groupes, chacun une fois.
    expect(
      prefetchFor('Une séance jambes et cuisses ?')
        .filter((call) => call.name === 'search_exercises')
        .map((call) => call.input.muscleGroupSlug),
    ).toEqual(['quadriceps', 'ischio-jambiers', 'fessiers']);
    // Un muscle nommé SANS séance demandée : une question, pas un plan.
    expect(names('Le squat, ça travaille les fessiers ?')).toEqual([]);
  });

  it('une séance demandée avec « faire » ou un conseil', () => {
    expect(names('Je dois faire une séance ce soir')).toContain('get_training_profile');
    expect(names('Tu me conseilles quoi comme séance aujourd’hui ?')).toContain(
      'get_training_profile',
    );
    expect(names('Tu me recommandes une séance courte ?')).toContain('get_training_profile');
  });

  it('un conseil AUTOUR de sa séance n’en demande pas une', () => {
    for (const request of [
      'Faut-il faire des étirements après la séance',
      'Je dois faire combien de séances par semaine ?',
      'Combien de séries faire par séance pour les pecs ?',
      'Je n’arrive pas à faire ma séance dos en entier',
      'Tu me conseilles de manger avant la séance ?',
      'Que me conseilles-tu pour la récup après la séance ?',
      'Un conseil pour mieux récupérer après ma séance ?',
      'Tu recommandes de boire pendant la séance ?',
      'Je peux faire mon programme deux fois par jour',
    ]) {
      expect(names(request)).not.toContain('get_training_profile');
    }
  });

  it('un muscle cité pour une douleur ou une exclusion n’est pas lu', () => {
    const searched = (request: string) =>
      prefetchFor(request)
        .filter((call) => call.name === 'search_exercises')
        .map((call) => call.input.muscleGroupSlug);
    expect(searched('J’ai mal au dos, tu me conseilles quelle séance ?')).toEqual([]);
    expect(searched('Une séance pecs sans les épaules')).toEqual(['pectoraux']);
    expect(searched('Mal aux épaules, tu me conseilles une séance jambes ?')).toEqual([
      'quadriceps',
      'ischio-jambiers',
      'fessiers',
    ]);
  });

  it('une question qui ne parle pas de ses données ne lit rien', () => {
    for (const request of [
      'Explique-moi la surcharge progressive',
      'Comment bien faire un soulevé de terre ?',
      'Merci beaucoup !',
      'C’est quoi un bon échauffement ?',
      'Combien de temps de repos max entre deux séries ?',
      'Le gainage statique, ça sert à quoi ?',
    ]) {
      expect(names(request)).toEqual([]);
    }
  });
});

import { resolveIntent } from './coach-intent';
import { asksForSession, prefetchFor as prefetchWith } from './coach-prefetch';

/** La lecture d'avance de ce message, seul dans son fil. */
const prefetchFor = (request: string) => prefetchWith(request, resolveIntent(request, []));

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
    // Débuter : ses séances, son profil, et de quoi composer sa séance.
    expect(names('Par où je commence ?').slice(0, 4)).toEqual([
      'get_recent_sessions',
      'get_training_profile',
      'get_personal_records',
      'search_exercises',
    ]);
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
    expect(names('Une séance full body rapide au poids du corps ?')[0]).toBe(
      'get_training_profile',
    );
    expect(names('Prépare-moi une séance haut du corps pour ce soir')[0]).toBe(
      'get_training_profile',
    );
    expect(names('Je veux un programme de 4 semaines')).toEqual(['get_training_profile']);
    // Parler de SA séance n'en demande pas une.
    expect(names('Mon programme me fatigue, normal ?')).not.toContain('get_training_profile');
  });

  it('une séance pour des muscles NOMMÉS : leurs exercices, lus d’avance', () => {
    // Constaté le 2 octobre 2026 : « je dois faire une séance quad fessiers »
    // n'était pas reconnue ; le modèle ne cherchait que « fessiers », et la
    // séance arrivait en texte, sans carte, faite de ponts fessiers.
    const calls = prefetchFor('je dois faire une séance quad fessiers que me conseilles tu?');
    // Et de quoi la régler : son profil, ses records (les charges), ses
    // dernières séances (ne pas refaire hier).
    expect(calls.map((call) => [call.name, call.input])).toEqual([
      ['get_training_profile', {}],
      ['get_personal_records', {}],
      ['get_recent_sessions', { limit: 3 }],
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

  it('une SÉANCE demandée, même sans verbe : le mot séance et un muscle suffisent', () => {
    // Constaté le 2 octobre 2026 : « tu me conseilles, quoi en séance quad
    // fessiers ? » n'était pas reconnue, et la séance arrivait en texte.
    for (const request of [
      'tu me conseilles, quoi en séance quad fessiers ?',
      'je dois faire une séance quad fessiers que me conseilles tu?',
      'Une séance full body rapide au poids du corps ?',
      'Prépare-moi une séance haut du corps pour ce soir',
      'séance pecs ?',
      'Quelle séance je peux faire ce soir ?',
      'Fais-moi une séance de 30 minutes',
      'Par où je commence ?',
    ]) {
      expect(asksForSession(request)).toBe(true);
    }
    for (const request of [
      'Je veux un programme de 4 semaines',
      'Je n’arrive pas à faire ma séance dos en entier',
      'Combien de séries faire par séance pour les pecs ?',
      'Tu me conseilles de manger avant la séance ?',
      'Ma séance d’hier était dure',
      'Le squat, ça travaille les fessiers ?',
      // Des questions AUTOUR d'une séance : une carte n'y répondrait pas.
      'Quelle est la durée idéale d’une séance ?',
      'Quel est le meilleur moment pour faire ma séance ?',
      'Quel échauffement avant une séance de pecs ?',
      'Je fais ma séance jambes demain, je mange quoi avant ?',
      'J’ai besoin de m’étirer après l’entraînement',
      'Combien de protéines après la séance pour récupérer ?',
      'Je reprends le sport après une blessure, des conseils ?',
      'Après une séance de jambes, j’ai mal aux cuisses, c’est normal ?',
      'Je peux faire des abdos à chaque séance ?',
    ]) {
      expect(asksForSession(request)).toBe(false);
    }
  });

  it('une séance sans muscle nommé : un peu de chaque grand groupe', () => {
    const searched = prefetchFor('Une séance pour ce soir ?').filter(
      (call) => call.name === 'search_exercises',
    );
    expect(searched.map((call) => call.input.muscleGroupSlug)).toEqual([
      'quadriceps',
      'fessiers',
      'pectoraux',
      'dos',
      'epaules',
      'abdominaux',
    ]);
    expect(searched.every((call) => call.input.limit === 8)).toBe(true);
    expect(
      prefetchFor('Une séance haut du corps')
        .filter((call) => call.name === 'search_exercises')
        .map((call) => call.input.muscleGroupSlug),
    ).toEqual(['pectoraux', 'dos', 'epaules']);
  });

  it('modifier une séance : le remplaçant nommé est cherché par son nom', () => {
    const intent = resolveIntent('Remplace le développé couché par des pompes.', [
      { role: 'assistant', content: 'Voici ta séance.', proposalId: 'p-1' },
    ]);
    expect(
      prefetchWith('Remplace le développé couché par des pompes.', intent)
        .filter((call) => call.name === 'search_exercises')
        .map((call) => call.input),
    ).toEqual([{ search: 'pompes' }]);
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
    expect(searched('J’ai mal au dos, tu me conseilles quelle séance ?')).toEqual([
      'quadriceps',
      'fessiers',
      'pectoraux',
      'epaules',
      'abdominaux',
    ]);
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

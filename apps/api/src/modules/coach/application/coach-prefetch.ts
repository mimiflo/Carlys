import { type CoachToolCall } from '../domain/coach-model.port';
import { fold } from './coach-exercise-search';

/**
 * Les lectures faites AVANT que le modèle n'écrive, quand la question porte
 * sur les données de la personne.
 *
 * Un petit modèle (Qwen3-4B) appelle ses outils de lecture quand il y pense,
 * et invente sinon : « Tu as déjà des records de soulevé de terre » sans en
 * avoir lu un seul (constaté le 1er octobre 2026). La consigne le lui
 * interdit ; ces lectures-ci ne lui laissent pas le choix. Elles lui
 * arrivent comme des outils DÉJÀ appelés, avec leurs résultats.
 *
 * Reconnaître la question est plus sûr que reconnaître l'oubli : la
 * personne dit « mon record », « est-ce que je progresse », « mon poids ».
 * Une question qui ne parle pas de ses données (« explique-moi la surcharge
 * progressive ») ne lit rien. La question est lue SANS ACCENTS : au
 * téléphone, « mes dernieres seances » s'écrit souvent ainsi.
 */
const READS: readonly (readonly [RegExp, readonly Omit<CoachToolCall, 'id'>[]])[] = [
  [
    /\b(mon|mes|ton|tes) (record|max)|\brecords?\b|\b1rm\b|\bmeilleure? perf/,
    [{ name: 'get_personal_records', input: {} }],
  ],
  [
    /\b(je progresse|progresser|ma progression|mes progres|progres|evolu\w*|stagn\w*|regularite|regulier|bilan|mes stats?|statistiques|combien de seances)\b/,
    [{ name: 'get_progress_overview', input: { period: 'month' } }],
  ],
  [
    /\b((mes|ma|mon|dernieres?|derniers?) (seances?|entrainements?)|j'ai (fait|souleve|couru)|hier|par ou|par quoi|je (commence|debute|reprends)|debutant\w*|reprise|reprendre)\b/,
    [{ name: 'get_recent_sessions', input: { limit: 5 } }],
  ],
  [
    /\b(mon poids|je pese|peser|pesee\w*|kilos?|maigri\w*|grossi\w*|perdu du poids|pris du poids)\b/,
    [{ name: 'get_body_weight_trend', input: {} }],
  ],
  [
    /\b(calories?|kcal|proteines?|glucides?|lipides?|macros?|mange\w*|repas|nutrition|regime)\b/,
    [
      { name: 'get_nutrition_targets', input: {} },
      { name: 'get_recent_meals', input: {} },
    ],
  ],
];

/**
 * Une DEMANDE de séance ou de programme, lue dans le message de la personne
 * (sans accents) — plus simple à reconnaître que les mille façons qu'a le
 * modèle de ne pas la faire (« l'adaptation est faite pour t'offrir une
 * séance réaliste », constaté, sans carte). Une seule source : la lecture
 * préalable du profil et l'occasion d'agir (announced-action.ts).
 */
const ASKED = [
  /\b(veux|voudrais|aimerais|fais|donne|propose|prepare|cree|construis|monte|besoin|quelle?)\b[^?.!]*\b(seance|programme|entrainement|plan|routine)s?\b/,
  // « Je dois faire une séance quad fessiers », « tu me conseilles quoi comme
  // séance » : UNE séance, pas un conseil autour de la sienne (« faire des
  // étirements après la séance », « tu me conseilles de manger avant »).
  /\b(faire|conseilles?|recommandes?|suggeres?)\b[^?.!]{0,30}\b(une|un|quelle|quoi comme) (nouvelle |petite |bonne )?(seance|programme|entrainement|routine)\b/,
  /\b(une|ma|la) (seance|programme)\b[^?.!]*\bpour\b/,
  // Sans verbe : « Une séance full body rapide au poids du corps ? »
  // (constaté : la séance arrivait écrite, sans carte). Pas « Ma séance
  // d'hier était dure », ni « Mon programme me fatigue ».
  /^\W*(une|un) (nouvelle |petite |bonne )?(seance|programme|routine)\b/,
  // Débuter : il attend un plan, pas un conseil (« Par où je commence ? »).
  /\bpar (ou|quoi) (je )?(commence|debute)|\bje (debute|commence la muscu|reprends le sport)/,
];

/**
 * Les groupes musculaires NOMMÉS dans une demande de séance, en slugs du
 * catalogue. Constaté le 2 octobre 2026 : pour « une séance quad fessiers »,
 * le modèle ne cherchait que « fessiers » et proposait trois ponts fessiers.
 * Leurs exercices lus d'avance, il compose avec ceux de CHAQUE groupe.
 */
const MUSCLES: readonly (readonly [RegExp, readonly string[]])[] = [
  [/\bquad\w*|\bcuisses?\b/, ['quadriceps']],
  [/\bischio\w*/, ['ischio-jambiers']],
  [/\bfess\w*|\bglute\w*/, ['fessiers']],
  [/\bjambes?\b|\bbas du corps\b/, ['quadriceps', 'ischio-jambiers', 'fessiers']],
  [/\bpecs?\b|\bpectora\w*|\bpoitrine\b/, ['pectoraux']],
  [/\bdos\b|\bdorsaux\b/, ['dos']],
  [/\bepaules?\b/, ['epaules']],
  [/\bbiceps\b/, ['biceps']],
  [/\btriceps\b/, ['triceps']],
  [/\bbras\b/, ['biceps', 'triceps']],
  [/\babdos?\b|\babdominaux\b/, ['abdominaux']],
  [/\bmollets?\b/, ['mollets']],
];

/** Un muscle qui fait mal, ou à épargner : surtout pas à travailler. */
const SPARED =
  /\b(mal (aux|au|a la|a l')|douleurs? (aux|au|a la|a l')|sans( les| le| la| l')?) ?[\w-]+/g;

function namedMuscles(question: string): Set<string> {
  const wanted = question.replace(SPARED, '');
  return new Set(MUSCLES.flatMap(([pattern, slugs]) => (pattern.test(wanted) ? slugs : [])));
}

export function asksForPlan(request: string): boolean {
  const question = folded(request);
  return ASKED.some((pattern) => pattern.test(question));
}

const folded = (request: string) => fold(request).replace(/[’`]/g, "'");

/**
 * Les lectures que mérite cette question, une seule fois chacune.
 *
 * Identifiants de neuf caractères alphanumériques (`lecture00`) : la forme
 * que Mistral exige de ses `tool_call_id`, et qu'Anthropic accepte.
 */
export function prefetchFor(request: string): CoachToolCall[] {
  const question = folded(request);
  const calls = new Map<string, Omit<CoachToolCall, 'id'>>();
  for (const [pattern, reads] of READS) {
    if (!pattern.test(question)) continue;
    for (const read of reads) calls.set(read.name, read);
  }
  // Une séance ou un programme demandé : il relit TOUJOURS le profil avant
  // de proposer (constaté) — un tour d'outil de moins, sur six — et les
  // exercices des muscles qu'elle nomme.
  if (asksForPlan(request)) {
    calls.set('get_training_profile', { name: 'get_training_profile', input: {} });
    for (const muscleGroupSlug of namedMuscles(question)) {
      calls.set(`search_exercises:${muscleGroupSlug}`, {
        name: 'search_exercises',
        input: { muscleGroupSlug },
      });
    }
  }
  return [...calls.values()].map((call, index) => ({
    id: `lecture${String(index).padStart(2, '0')}`,
    ...call,
  }));
}

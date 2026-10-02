import { type CoachToolCall, type CoachToolResult } from '../domain/coach-model.port';
import { type CoachIntent } from './coach-intent';
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
  [/\bhaut du corps\b/, ['pectoraux', 'dos', 'epaules']],
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

const musclesIn = (text: string) =>
  new Set(MUSCLES.flatMap(([pattern, slugs]) => (pattern.test(text) ? slugs : [])));

/** Les muscles qu'il veut travailler, en slugs du catalogue (pas ceux qu'il épargne). */
export const namedMuscles = (question: string) => musclesIn(question.replace(SPARED, ''));

/** Une question sur SES données (records, progression, poids, repas…). */
export function asksForData(request: string): boolean {
  const question = folded(request);
  return READS.some(([pattern]) => pattern.test(question));
}

export function asksForPlan(request: string): boolean {
  const question = folded(request);
  return ASKED.some((pattern) => pattern.test(question));
}

const PROGRAM = /\b(programme|plan)s?\b/;
const SESSION = '(seance|entrainement|routine|workout)s?';

/** Les façons de DEMANDER une séance : une séance, pas la sienne. */
const SESSION_ASKED = [
  // « fais-moi une séance », « je dois faire une séance quad fessiers »,
  // « tu me conseilles, quoi en séance quad fessiers ? »
  new RegExp(
    `\\b(veux|voudrais|aimerais|fais|faire|donne|propose|prepare|cree|construis|monte|conseilles?|recommandes?|suggeres?)\\b[^?.!]{0,40}\\b(une|un|quoi comme|quoi en) (nouvelle |petite |bonne |autre )?${SESSION}\\b`,
  ),
  // « Quelle séance je peux faire ce soir ? » — pas « quelle est la durée ».
  new RegExp(`\\bquelle? ${SESSION}\\b`),
  // Sans verbe : « Une séance pour ce soir ? »
  new RegExp(`^\\W*(une|un) (nouvelle |petite |bonne |autre )?${SESSION}\\b`),
  /\bpar (ou|quoi) (je )?(commence|debute)\b/,
];

/** Le mot séance, sans article qui en fasse la sienne ou un moment. */
const BARE_SESSION = new RegExp(`(^|\\b(en|de|une|un|nouvelle) |^\\W*)${SESSION}\\b`);
/** Un moment autour d'une séance (« après la séance », « à chaque séance ») : pas une demande. */
const AROUND_SESSION = /\b(avant|apres|pendant|chaque|par) (une |la |ma |l')?(seance|entrainement)/;

/**
 * Une SÉANCE à composer (pas un programme) : demandée (« fais-moi une
 * séance », « quelle séance ce soir ? »), ou le mot séance avec un muscle
 * (« séance pecs ? » ; « tu me conseilles, quoi en séance quad fessiers ? »,
 * constaté le 2 octobre 2026 : non reconnue, elle arrivait en texte, sans
 * carte). Elle se compose alors à coup sûr (coach-session.ts) — et rien
 * d'autre ne s'écrit : une question AUTOUR d'une séance (« quel échauffement
 * avant une séance ? », « ma séance jambes demain, je mange quoi ? ») n'en
 * est donc jamais une.
 */
export function asksForSession(request: string): boolean {
  const question = folded(request);
  if (PROGRAM.test(question)) return false;
  if (SESSION_ASKED.some((pattern) => pattern.test(question))) return true;
  return (
    BARE_SESSION.test(question) && !AROUND_SESSION.test(question) && namedMuscles(question).size > 0
  );
}

/** Sans muscle nommé, un peu de chaque grand groupe : de quoi composer un corps entier. */
const WHOLE_BODY = ['quadriceps', 'fessiers', 'pectoraux', 'dos', 'epaules', 'abdominaux'];

/** La question sans accents ni majuscules, apostrophes droites : la forme que lisent les règles. */
export const folded = (request: string) => fold(request).replace(/[’`]/g, "'");

/** « Remplace le développé couché par des pompes » : ce qui doit entrer dans la séance. */
const REPLACEMENT =
  /\bpar (des |du |de la |de l'|le |la |les |un |une )?([a-z' -]{3,40}?)(?=[.,!?]|$| et | pour )/;

/**
 * De quoi composer une séance exigée (coach-session.ts) : son profil, ses
 * records (les charges), ses dernières séances (ne pas refaire hier), et les
 * exercices dont chaque muscle nommé est le muscle PRINCIPAL — tous : le
 * catalogue rend par ordre alphabétique, et une coupe à six perdait les
 * squats. Sans muscle nommé, huit de chaque grand groupe, sauf pour modifier
 * une séance (elle fournit les siens) ; jamais un muscle cité pour une
 * douleur ou une exclusion.
 */
function workoutReads(request: string, kind: CoachIntent['kind']) {
  const question = folded(request);
  const reads: [string, Omit<CoachToolCall, 'id'>][] = [
    ['get_training_profile', { name: 'get_training_profile', input: {} }],
    ['get_personal_records', { name: 'get_personal_records', input: {} }],
    ['get_recent_sessions', { name: 'get_recent_sessions', input: { limit: 3 } }],
  ];
  const named = [...namedMuscles(question)];
  const spared = musclesIn((question.match(SPARED) ?? []).join(' '));
  const searches: Record<string, unknown>[] =
    named.length > 0
      ? named.map((muscleGroupSlug) => ({ muscleGroupSlug }))
      : kind === 'WORKOUT_MODIFICATION_REQUIRED'
        ? []
        : WHOLE_BODY.filter((slug) => !spared.has(slug)).map((muscleGroupSlug) => ({
            muscleGroupSlug,
            limit: 8,
          }));
  const replacement = REPLACEMENT.exec(question)?.[2]?.trim();
  if (replacement !== undefined) searches.push({ search: replacement });
  for (const input of searches) {
    const key = `search_exercises:${String(input.muscleGroupSlug ?? input.search)}`;
    reads.push([key, { name: 'search_exercises', input }]);
  }
  return reads;
}

/**
 * Les lectures que mérite cette question, une seule fois chacune.
 *
 * Identifiants de neuf caractères alphanumériques (`lecture00`) : la forme
 * que Mistral exige de ses `tool_call_id`, et qu'Anthropic accepte.
 */
export function prefetchFor(request: string, intent: CoachIntent): CoachToolCall[] {
  const question = folded(request);
  const calls = new Map<string, Omit<CoachToolCall, 'id'>>();
  for (const [pattern, reads] of READS) {
    if (!pattern.test(question)) continue;
    for (const read of reads) calls.set(read.name, read);
  }
  // Un programme demandé : il relit TOUJOURS le profil avant de proposer
  // (constaté) — un tour d'outil de moins, sur six.
  if (intent.kind === 'PROGRAM') {
    calls.set('get_training_profile', { name: 'get_training_profile', input: {} });
  }
  if ('request' in intent) {
    for (const [key, call] of workoutReads(intent.request ?? request, intent.kind)) {
      calls.set(key, call);
    }
  }
  return [...calls.values()].map((call, index) => ({
    id: `lecture${String(index).padStart(2, '0')}`,
    ...call,
  }));
}

/** Chaque lecture avec son résultat : `CoachTools.run` en rend un par lecture, dans l'ordre. */
export function withResults(
  reads: readonly CoachToolCall[],
  results: readonly CoachToolResult[],
): { call: CoachToolCall; result: CoachToolResult }[] {
  return reads.flatMap((call, i) => {
    const result = results[i];
    return result === undefined ? [] : [{ call, result }];
  });
}

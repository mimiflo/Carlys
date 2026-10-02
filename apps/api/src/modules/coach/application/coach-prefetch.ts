import { type CoachToolCall } from '../domain/coach-model.port';

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
 * progressive ») ne coûte rien : aucune lecture.
 */
const READS: readonly (readonly [RegExp, readonly Omit<CoachToolCall, 'id'>[]])[] = [
  [
    /(?<!\p{L})(records?|max|maximum|1rm|meilleure? perf\p{L}*)(?!\p{L})/iu,
    [{ name: 'get_personal_records', input: {} }],
  ],
  [
    /(?<!\p{L})(progresse|progresser|ma progression|progrès|évolu\p{L}*|stagn\p{L}*|régul\p{L}*|bilan|stat\p{L}*|combien de séances)(?!\p{L})/iu,
    [{ name: 'get_progress_overview', input: { period: 'month' } }],
  ],
  [
    /(?<!\p{L})((mes|ma|mon|dernières?|derniers?) (séances?|entraînements?)|j['’]ai (fait|soulevé|couru)|hier|par où|par quoi|je (commence|débute|reprends)|débutant\p{L}*|reprise|reprendre)(?!\p{L})/iu,
    [{ name: 'get_recent_sessions', input: { limit: 5 } }],
  ],
  [
    /(?<!\p{L})(mon poids|pèse|peser|pesée|kilos?|maigri\p{L}*|grossi\p{L}*|perdu du poids|pris du poids)(?!\p{L})/iu,
    [{ name: 'get_body_weight_trend', input: {} }],
  ],
  [
    /(?<!\p{L})(calories?|kcal|protéines?|glucides?|lipides?|macros?|mange\p{L}*|repas|nutrition|régime)(?!\p{L})/iu,
    [
      { name: 'get_nutrition_targets', input: {} },
      { name: 'get_recent_meals', input: {} },
    ],
  ],
];

/** Les lectures que mérite cette question, une seule fois chacune. */
export function prefetchFor(request: string): CoachToolCall[] {
  const calls = new Map<string, Omit<CoachToolCall, 'id'>>();
  for (const [pattern, reads] of READS) {
    if (!pattern.test(request)) continue;
    for (const read of reads) calls.set(read.name, read);
  }
  return [...calls.values()].map((call, index) => ({ id: `lecture_${index}`, ...call }));
}

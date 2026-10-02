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
 * Les lectures que mérite cette question, une seule fois chacune.
 *
 * Identifiants de neuf caractères alphanumériques (`lecture00`) : la forme
 * que Mistral exige de ses `tool_call_id`, et qu'Anthropic accepte.
 */
export function prefetchFor(request: string): CoachToolCall[] {
  const question = fold(request).replace(/[’`]/g, "'");
  const calls = new Map<string, Omit<CoachToolCall, 'id'>>();
  for (const [pattern, reads] of READS) {
    if (!pattern.test(question)) continue;
    for (const read of reads) calls.set(read.name, read);
  }
  return [...calls.values()].map((call, index) => ({ id: `lecture0${index}`, ...call }));
}

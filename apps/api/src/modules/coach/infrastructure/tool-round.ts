import { PROPOSE_PROGRAM_TOOL, PROPOSE_SESSION_TOOL } from '../application/coach.tool-definitions';
import { type CoachToolCall, type CoachTurnInput } from '../domain/coach-model.port';
import { USER_DATA_TOOLS } from './announced-action';
import { toolReply } from './openai-compatible.helpers';

/**
 * Les derniers tours d'outils servent à CONCLURE : plus de lecture, seulement
 * la proposition et la réponse.
 *
 * Constaté le 2 octobre 2026 (« Une séance full body rapide au poids du
 * corps ? », trois essais) : Qwen3-4B lit une chose par tour — modèles,
 * séances, progression, records, profil, puis plusieurs recherches, la même
 * deux fois — et les six tours passent avant qu'il ne propose : « Je n'ai pas
 * réussi à aboutir » une fois sur trois, une séance écrite sans carte les
 * deux autres. Une lecture refusée lui revient comme une erreur qui dit quoi
 * faire ; il lui reste deux tours pour proposer et répondre.
 */
export const WRAP_UP_ROUNDS = 2;

const ENOUGH_READ =
  'Plus de lecture dans ce tour : réponds maintenant avec ce que tu as déjà lu. Une séance ' +
  'se propose avec propose_session, un programme avec propose_program.';

const PROPOSALS = new Set([PROPOSE_SESSION_TOOL, PROPOSE_PROGRAM_TOOL]);

/**
 * Exécute les outils d'un tour (`propose_session` est seulement retenue, les
 * lectures sont refusées quand `wrapUp`) et ajoute l'appel et ses résultats à
 * `messages`. `true` : des données de la personne ont été lues pour de bon.
 */
export async function runToolRound(
  input: CoachTurnInput,
  calls: CoachToolCall[],
  answer: { content: unknown; tool_calls: unknown[] },
  messages: Record<string, unknown>[],
  wrapUp: boolean,
): Promise<boolean> {
  const refused = wrapUp ? calls.filter((call) => !PROPOSALS.has(call.name)) : [];
  const allowed = calls.filter((call) => !refused.includes(call));
  input.onToolCalls?.(allowed);
  const results = [
    ...(await input.runTools(allowed.filter((call) => call.name !== PROPOSE_SESSION_TOOL))),
    ...refused.map((call) => ({ id: call.id, content: ENOUGH_READ, isError: true })),
  ];

  messages.push({
    role: 'assistant',
    // Chaîne vide plutôt que null : la forme de l'exemple de Mistral.
    content: answer.content ?? '',
    tool_calls: answer.tool_calls,
  });
  for (const call of calls) {
    messages.push({ role: 'tool', tool_call_id: call.id, content: toolReply(call, results) });
  }
  return results.some(
    (result) =>
      result.isError !== true &&
      USER_DATA_TOOLS.has(calls.find((call) => call.id === result.id)?.name ?? ''),
  );
}

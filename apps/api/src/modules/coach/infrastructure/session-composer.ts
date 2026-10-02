import { compositionPrompt, compositionSchema } from '../application/coach-session';
import { fallbackChoice, parseChoice, sessionProposal } from '../application/coach-session-choice';
import { COMPOSE_STEP } from '../application/coach-steps';
import {
  type CoachComposition,
  type CoachGeneration,
  type CoachTurnInput,
  type CoachTurnOutput,
  type CoachTurnUsage,
} from '../domain/coach-model.port';
import { type ContextBudget } from './context-budget';
import { type CoachWorkerRequests } from './coach-worker-requests';
import { endOfCompletion, endOfError } from './generation-end';
import { addUsage, textOf, unavailable } from './openai-compatible.helpers';

/**
 * Le JSON d'une séance tient en ≈ 230 jetons (mesuré) : au-delà, le modèle
 * réfléchit hors grammaire, et le repli vaut mieux qu'une longue attente.
 */
const COMPOSE_MAX_TOKENS = 512;

/**
 * La séance demandée, composée d'UN appel à sortie contrainte
 * (`response_format`, application/coach-session.ts) : un message et une
 * séance dont chaque exercice est pris dans la composition. Sans réponse
 * utilisable (panne, échéance, format ignoré), le serveur compose seul :
 * la carte arrive toujours. Seule l'annulation par la personne remonte.
 */
export async function composeSession(
  complete: CoachWorkerRequests['complete'],
  input: CoachTurnInput,
  {
    composition,
    turn,
  }: {
    composition: CoachComposition;
    turn: { signal: AbortSignal; maxTokens: number; budget: ContextBudget; usage: CoachTurnUsage };
  },
): Promise<Pick<CoachTurnOutput, 'text' | 'proposal' | 'worker' | 'generation' | 'composed'>> {
  // Sa réflexion : « Je prépare ta séance » (coach-steps.ts).
  // En cours tant qu'il écrit ; le contrat du tour la coche (coach-actions.ts).
  input.onToolCalls?.([{ id: 'seance00', name: COMPOSE_STEP, input: {} }]);
  const system = [
    { role: 'system', content: input.system },
    ...(input.systemPerUser ? [{ role: 'system', content: input.systemPerUser }] : []),
  ];
  const history = input.history.map((message) => ({ ...message }));
  const messages = [
    ...system,
    ...history,
    { role: 'user', content: compositionPrompt(composition) },
  ];
  const wanted = Math.min(COMPOSE_MAX_TOKENS, turn.maxTokens);
  turn.budget.trim(messages, system.length, history.length, wanted);
  const maxTokens = Math.min(wanted, turn.budget.room(messages));
  const generation: CoachGeneration = {
    finishReason: 'UNKNOWN',
    ends: [],
    continuations: 0,
    recovered: 0,
    unneeded: 0,
    truncated: false,
  };
  let worker: string | undefined;
  let content = '';
  let failure: string | undefined;
  try {
    const { completion, served } = await complete(
      {
        messages,
        response_format: {
          type: 'json_schema',
          json_schema: { name: 'seance', strict: true, schema: compositionSchema(composition) },
        },
      },
      turn.signal,
      // En flux, pour le délai d'inactivité ; le JSON ne se montre pas.
      input.onText && (() => undefined),
      maxTokens,
    );
    addUsage(turn.usage, completion);
    worker = served;
    generation.finishReason = endOfCompletion(completion);
    content = textOf(completion.choices?.[0]?.message?.content);
  } catch (error) {
    generation.finishReason = endOfError(error, turn.signal, input.signal);
    // Annulée par la personne : comme la boucle d'outils, rendue au quota.
    if (input.signal?.aborted === true) {
      unavailable(error, turn.usage, false, generation.finishReason);
    }
    // Toute autre panne : le serveur compose seul, et le journal dit pourquoi
    // (un fournisseur qui refuserait `response_format` se verrait ici).
    failure = error instanceof Error ? error.message : String(error);
  }
  generation.ends.push(generation.finishReason);
  const choice = parseChoice(content, composition);
  const chosen = choice ?? fallbackChoice(composition);
  input.onText?.(chosen.message);
  return {
    text: chosen.message,
    proposal: sessionProposal(chosen, composition),
    worker,
    generation,
    composed:
      choice === null
        ? { by: 'server', failure: failure ?? `réponse inutilisable (${generation.finishReason})` }
        : { by: 'model' },
  };
}

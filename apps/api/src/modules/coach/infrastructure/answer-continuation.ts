import { type CoachTurnUsage, type FinishReason } from '../domain/coach-model.port';
import { type ChatCompletion } from './chat-completion-stream';
import {
  endOfCompletion,
  endOfError,
  GenerationFailure,
  looksSuspended,
  recoverable,
} from './generation-end';
import { AnswerStream, atWordBoundary, continuationPrompt } from './answer-stream';
import { addUsage, textOf } from './openai-compatible.helpers';

/**
 * La reprise d'une réponse coupée, par l'ORCHESTRATION et non par la
 * consigne : quand un appel s'arrête avant la fin de la réponse (plafond de
 * jetons, flux rompu, fin manifestement en suspens), le client redemande la
 * SUITE — jamais la réponse entière — et la raccorde, dans la même bulle.
 *
 * Aucun second appel pour une réponse finie : la reprise ne part que sur un
 * signe de coupure (`length`, panne, `looksSuspended`) ; jamais sur un appel
 * d'outil, jamais après l'annulation par la personne.
 */

/** La requête au modèle du client : charge utile, signal, flux, plafond, worker. */
export type Complete = (
  payload: Record<string, unknown>,
  signal: AbortSignal,
  onText: ((delta: string) => void) | undefined,
  maxOutputTokens: number,
  prefer?: string,
) => Promise<{ completion: ChatCompletion; served: string }>;

/** Le bilan d'un appel et de ses reprises : ce que mesurent journaux et métriques. */
export interface AnswerReport {
  /** La fin de chaque appel, dans l'ordre. */
  ends: FinishReason[];
  continuations: number;
  /** Reprises qui ont terminé la réponse. */
  recovered: number;
  /** Reprises superflues : le modèle a répondu « FIN », la réponse était finie. */
  unneeded: number;
  /** Réponse rendue incomplète, faute de reprise possible. */
  truncated: boolean;
}

interface AnswerTurn {
  messages: Record<string, unknown>[];
  tools: unknown[];
  signal: AbortSignal;
  cancelled: AbortSignal | undefined;
  onText: ((delta: string) => void) | undefined;
  maxTokens: number;
  worker: string | undefined;
  maxContinuations: number;
  /**
   * Une fin voulue (`stop`) n'est jamais une coupure : une proposition est
   * déjà faite, « Voici la séance : » précède sa carte.
   */
  trustStop: boolean;
  usage: CoachTurnUsage;
}

/**
 * Un appel au modèle, ses reprises s'il le faut, et la réponse ENTIÈRE :
 * contenu raccordé, appels d'outils de la dernière complétion. Une panne
 * avant tout texte remonte telle quelle (rien à reprendre : l'erreur est
 * dite, la question se renvoie) ; une
 * panne APRÈS du texte montré repart de ce texte, ou le rend incomplet.
 */
export async function completeAnswer(
  complete: Complete,
  turn: AnswerTurn,
): Promise<{ completion: ChatCompletion; served: string | undefined; report: AnswerReport }> {
  const stream = new AnswerStream(turn.onText);
  const report: AnswerReport = {
    ends: [],
    continuations: 0,
    recovered: 0,
    unneeded: 0,
    truncated: false,
  };
  let served = turn.worker;
  // `null` : l'appel a lâché après du texte, une reprise peut en repartir.
  const call = async (messages: Record<string, unknown>[]) => {
    try {
      const result = await complete(
        { messages, tools: turn.tools },
        turn.signal,
        turn.onText && stream.push,
        turn.maxTokens,
        served,
      );
      served = result.served;
      addUsage(turn.usage, result.completion);
      // Sans flux, le texte arrive d'un bloc.
      const content = result.completion.choices?.[0]?.message?.content;
      if (!turn.onText) stream.push(typeof content === 'string' ? content : textOf(content));
      const end = endOfCompletion(result.completion);
      report.ends.push(end);
      return { end, completion: result.completion as ChatCompletion | null };
    } catch (error) {
      const end = endOfError(error, turn.signal, turn.cancelled);
      report.ends.push(end);
      if (stream.text.trim() === '' || !recoverable(end, turn.signal)) throw error;
      return { end, completion: null };
    }
  };

  let last = await call(turn.messages);
  // Une reprise rendue impossible : la réponse montrée reste, incomplète —
  // sauf s'il n'en reste pas un mot entier, et la panne remonte.
  const truncate = (failure?: unknown) => {
    if (atWordBoundary(stream.text).trim() === '') {
      throw failure instanceof Error
        ? failure
        : new GenerationFailure('Coach : réponse coupée.', last.end);
    }
    stream.truncate(last.end !== 'NORMAL_STOP');
    report.truncated = true;
  };
  while (cutShort(last.completion, last.end, stream.text, turn.trustStop)) {
    if (report.continuations === turn.maxContinuations) {
      truncate();
      break;
    }
    report.continuations += 1;
    const cause = last.end;
    const base = stream.resume(cause !== 'NORMAL_STOP');
    let failure: unknown;
    const next = await call([
      ...turn.messages,
      { role: 'assistant', content: base },
      { role: 'user', content: continuationPrompt(base) },
    ]).catch((error: unknown) => {
      // Sans recours (échéance du tour, contexte plein). Seule l'annulation remonte.
      if (turn.cancelled?.aborted === true) throw error;
      failure = error;
      return null;
    });
    const settled = stream.settle();
    // « FIN » après une vraie coupure (plafond, panne) : le modèle se trompe.
    if (next === null || (settled === 'fin' && cause !== 'NORMAL_STOP')) {
      truncate(failure);
      break;
    }
    // Une reprise qui recommence sans rejoindre la réponse : une autre, s'il en reste.
    if (settled === 'rejected') continue;
    last = next;
    if (settled === 'fin') {
      report.unneeded += 1;
      break;
    }
    if (!cutShort(last.completion, last.end, stream.text, turn.trustStop)) report.recovered += 1;
  }
  stream.flush();
  const choice = last.completion?.choices?.[0];
  return {
    completion: {
      usage: last.completion?.usage ?? null,
      choices: [
        {
          finish_reason: choice?.finish_reason ?? null,
          message: { content: stream.text, tool_calls: choice?.message?.tool_calls ?? [] },
        },
      ],
    },
    served,
    report,
  };
}

/** L'appel s'est-il arrêté avant la fin de la réponse ? Jamais sur un appel d'outil. */
function cutShort(
  completion: ChatCompletion | null,
  end: FinishReason,
  text: string,
  trustStop: boolean,
): boolean {
  if ((completion?.choices?.[0]?.message?.tool_calls?.length ?? 0) > 0) return false;
  if (text.trim() === '') return false;
  if (completion === null) return true;
  return end === 'MAX_TOKENS' || (end === 'NORMAL_STOP' && !trustStop && looksSuspended(text));
}

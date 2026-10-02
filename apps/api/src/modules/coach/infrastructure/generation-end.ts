import { ServiceUnavailableException } from '@nestjs/common';
import { type FinishReason } from '../domain/coach-model.port';
import { type ChatCompletion } from './chat-completion-stream';

/**
 * La FIN d'une génération, et ce qu'elle veut dire.
 *
 * Que le moteur cesse d'envoyer des jetons ne dit pas que la réponse est
 * finie. Mesuré sur Qwen3-4B servi par Ollama 0.34 (2 octobre 2026) :
 *
 * - au plafond de jetons, `finish_reason` vaut `length` et le texte s'arrête
 *   au milieu d'un mot (« …en fonction de l'é ») ;
 * - quand la réponse déborde du contexte (8 192), Ollama DÉCALE le contexte
 *   et continue jusqu'au plafond : la fin reste un `length` ;
 * - un message trop long pour le contexte est refusé d'emblée (HTTP 400
 *   `exceed_context_size_error`) : une erreur, pas une coupure ;
 * - un `stop` est une fin voulue par le modèle — presque toujours une vraie.
 */

/** La fin déclarée par le moteur, telle quelle. */
export function endOfCompletion(completion: ChatCompletion): FinishReason {
  const reason = completion.choices?.[0]?.finish_reason;
  if (reason === 'length') return 'MAX_TOKENS';
  if (reason === 'stop' || reason === 'tool_calls' || reason === 'end_turn') return 'NORMAL_STOP';
  return 'UNKNOWN';
}

/** Une panne qui sait ce qu'elle est : flux rompu, contexte dépassé, worker en échec. */
export class GenerationFailure extends ServiceUnavailableException {
  constructor(
    message: string,
    readonly end: FinishReason,
  ) {
    super(message);
  }
}

/**
 * La fin d'un appel qui a échoué. `turn` est le signal du tour (échéance et
 * annulation) ; `cancelled`, celui de la personne seule.
 */
export function endOfError(
  error: unknown,
  turn: AbortSignal,
  cancelled: AbortSignal | undefined,
): FinishReason {
  if (cancelled?.aborted === true) return 'CLIENT_DISCONNECT';
  if (error instanceof GenerationFailure) return error.end;
  if (turn.aborted) return 'TIMEOUT';
  return 'UNKNOWN';
}

/**
 * Les pannes dont une réponse partielle peut repartir, sur un autre essai —
 * jamais l'échéance du tour (`turn` déjà échu), ni l'annulation.
 */
export function recoverable(end: FinishReason, turn: AbortSignal): boolean {
  return !turn.aborted && (end === 'TIMEOUT' || end === 'WORKER_ERROR' || end === 'STREAM_ERROR');
}

/**
 * La réponse s'arrête-t-elle MANIFESTEMENT en suspens, malgré un `stop` ?
 *
 * Une réponse courte (« Oui, c'est possible. »), une liste finie, un émoji
 * final sont des fins. Comptent des signaux de syntaxe que rien ne termine :
 * un bloc de code ou une parenthèse ouverts, deux-points ou virgule finaux,
 * une puce vide, un mot-outil final (« …travailler principalement les »),
 * un appel d'outil écrit en texte et inachevé — et une PHRASE qui s'arrête
 * sur un mot, sans ponctuation (« Le développé couché travaille »).
 *
 * Mesuré (2 octobre 2026) : aucune des 79 réponses complètes de Qwen3-4B
 * relevées ne finit sa dernière phrase sans ponctuation ; les trois arrêtées
 * en plein milieu (« …et améliore ») y finissaient toutes. Une liste, un
 * titre ou un tableau finissent sans point : leur dernière ligne n'est pas
 * une phrase. Un faux positif coûte une reprise qui répond « FIN ».
 */
export function looksSuspended(text: string): boolean {
  const trimmed = text.trimEnd();
  if (trimmed === '') return false;
  if ((trimmed.match(/```/g)?.length ?? 0) % 2 === 1) return true;
  if (/<tool_call>(?![\s\S]*<\/tool_call>)/.test(trimmed)) return true;
  if (count(trimmed, '(') > count(trimmed, ')')) return true;
  if (count(trimmed, '«') > count(trimmed, '»')) return true;
  if (/[:,;]$/.test(trimmed)) return true;
  // Une puce ou un numéro, et rien derrière.
  if (/(^|\n)\s*([-*•]|\d+[.)])$/.test(trimmed)) return true;
  // Une phrase (ni puce, ni numéro, ni titre, ni tableau) qui finit sur un mot.
  const lastLine = trimmed.slice(trimmed.lastIndexOf('\n') + 1).trim();
  if (!/^([-*•#|]|\d+[.)])/.test(lastLine) && /[\p{L}\p{N}]$/u.test(lastLine)) return true;
  // Un mot-outil final, même dans une liste : la ligne attend sa suite.
  return /(?<!\p{L})(de|du|des|le|la|les|l'|l’|un|une|et|ou|à|au|aux|en|pour|par|avec|sans|sur|sous|dans|vers|que|qui|mais|donc|car|ton|ta|tes|mon|ma|mes|son|sa|ses|ce|cet|cette|ces|d'|d’|qu'|qu’|est|sont|très|plus|moins)$/iu.test(
    trimmed,
  );
}

function count(text: string, char: string): number {
  return text.split(char).length - 1;
}

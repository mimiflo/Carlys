import { HttpException, ServiceUnavailableException } from '@nestjs/common';
import {
  CoachProviderUnavailableException,
  type CoachToolCall,
  type FinishReason,
  type CoachToolResult,
  type CoachTurnUsage,
} from '../domain/coach-model.port';
import { PROPOSE_SESSION_TOOL } from '../application/coach.tool-definitions';
import { type ChatCompletion, readChatStream } from './chat-completion-stream';

/**
 * Les outils du client compatible OpenAI (`openai-compatible.client.ts`) :
 * lecture d'une réponse, erreurs, appels d'outils.
 */

/**
 * Les lectures faites avant le modèle (coach-prefetch.ts), sous la forme
 * d'un appel d'outils et de leurs résultats.
 */
export function prefetchedMessages(
  prefetched: readonly { call: CoachToolCall; result: CoachToolResult }[],
): Record<string, unknown>[] {
  if (prefetched.length === 0) return [];
  return [
    {
      role: 'assistant',
      content: '',
      tool_calls: prefetched.map(({ call }) => ({
        id: call.id,
        type: 'function',
        function: { name: call.name, arguments: JSON.stringify(call.input) },
      })),
    },
    ...prefetched.map(({ call, result }) => ({
      role: 'tool',
      tool_call_id: call.id,
      content: toolReply(call, [result]),
    })),
  ];
}

/** Ajoute à `usage` les jetons qu'une complétion déclare. */
export function addUsage(usage: CoachTurnUsage, completion: ChatCompletion): void {
  usage.inputTokens += completion.usage?.prompt_tokens ?? 0;
  usage.outputTokens += completion.usage?.completion_tokens ?? 0;
  usage.cacheReadTokens += completion.usage?.prompt_tokens_details?.cached_tokens ?? 0;
}

/** Le flux recomposé, ou le corps JSON d'une réponse d'un bloc. */
export async function readCompletion(
  response: Response,
  onText?: (delta: string) => void,
  onChunk?: () => void,
): Promise<ChatCompletion> {
  if (onText) {
    return readChatStream(response, onText, onChunk);
  }
  const body: unknown = await response.json();
  if (typeof body !== 'object' || body === null) {
    throw new ServiceUnavailableException('Coach : réponse illisible.');
  }
  return body;
}

/**
 * Statut refusé, réseau coupé, échéance dépassée, JSON illisible : 503, avec
 * les jetons déjà consommés. Le message ne sert qu'aux JOURNAUX (le filtre
 * masque tout 5xx) : notre propre texte (avec, pour un 429 ou un 5xx, la
 * raison du fournisseur, voir `refusalReason`), ou le NOM de l'erreur,
 * jamais son message, qui peut citer le corps de la réponse.
 */
export function unavailable(
  error: unknown,
  usage: CoachTurnUsage,
  shown: boolean,
  end: FinishReason,
): never {
  // Un flux coupé ne dit pas ce qu'il a coûté (l'usage n'arrive qu'à la
  // fin) : du texte montré prouve des jetons consommés, le message n'est
  // donc PAS rendu (`refundIfUnavailable` ne rend qu'à zéro jeton).
  if (shown && usage.inputTokens === 0) {
    usage.inputTokens = 1;
  }
  const reason =
    error instanceof HttpException
      ? error.message
      : `Coach : fournisseur injoignable (${error instanceof Error ? error.name : 'inconnue'}).`;
  throw new CoachProviderUnavailableException(reason, usage, end);
}

/**
 * Le corps d'un refus (4xx) n'est jamais lu : il peut citer le message de la
 * personne. Celui d'un 429 ou d'un 5xx dit POURQUOI le fournisseur refuse
 * (débit, volume du mois, capacité saturée) : son seul champ `message`,
 * tronqué, part au journal, avec les en-têtes de limites. Ce sont eux qui
 * départagent : `x-ratelimit-limit-req-minute=0` dit que le modèle n'a AUCUNE
 * allocation dans l'offre (changer `COACH_MODEL`), une limite pleine dit
 * qu'il faut attendre.
 */
export async function refusalReason(response: Response, retryable: boolean): Promise<string> {
  if (!retryable) {
    await response.body?.cancel();
    return '';
  }
  const body = (await response.json().catch(() => null)) as {
    message?: unknown;
    error?: { message?: unknown };
  } | null;
  const message = body?.message ?? body?.error?.message;
  const limits: string[] = [];
  response.headers.forEach((value, name) => {
    if (/ratelimit|retry-after/i.test(name)) {
      limits.push(`${name}=${value.slice(0, 40)}`);
    }
  });
  return (
    (typeof message === 'string' ? ` (${message.slice(0, 160)})` : '') +
    (limits.length > 0 ? ` [${limits.join(', ').slice(0, 300)}]` : '')
  );
}

/** Ce que le modèle relit de chaque appel, dans l'ordre de ses appels. */
export function toolReply(call: CoachToolCall, results: CoachToolResult[]): string {
  if (call.name === PROPOSE_SESSION_TOOL) {
    // Accusé de réception, pour que le modèle puisse conclure son tour.
    return 'Proposition reçue.';
  }
  const result = results.find((candidate) => candidate.id === call.id);
  if (result === undefined) {
    return 'Erreur : outil sans résultat.';
  }
  return result.isError ? `Erreur : ${result.content}` : result.content;
}

/** Chaîne JSON (le cas général) ou objet (Ollama) ; illisible : `{}`. */
export function parseArguments(raw: unknown): Record<string, unknown> {
  try {
    const value: unknown = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return typeof value === 'object' && value !== null && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};
  } catch {
    // Les outils retombent sur leurs défauts ; le validateur rejette une
    // proposition vide.
    return {};
  }
}

/** Texte simple, ou morceaux d'un modèle qui raisonne : seul le texte final. */
export function textOf(content: unknown): string {
  if (typeof content === 'string') {
    return content.trim();
  }
  if (!Array.isArray(content)) {
    return '';
  }
  return (content as unknown[])
    .filter(
      (part): part is { type: 'text'; text: string } =>
        typeof part === 'object' && part !== null && 'type' in part && part.type === 'text',
    )
    .map((part) => part.text)
    .join('')
    .trim();
}

/**
 * `next` redit-il surtout `before` ? Après l'occasion d'agir, le modèle
 * réécrit souvent la séance qu'il venait de décrire (constaté : la même
 * séance deux fois dans la réplique archivée). Six mots sur dix déjà dits :
 * c'est une redite, la première version suffit.
 */
export function restates(next: string, before: string): boolean {
  if (before === '') return false;
  const said = new Set(wordsOf(before));
  const fresh = wordsOf(next);
  return fresh.length > 0 && fresh.filter((word) => said.has(word)).length / fresh.length >= 0.6;
}

function wordsOf(text: string): string[] {
  return text.toLowerCase().match(/[\p{L}\p{N}]{3,}/gu) ?? [];
}

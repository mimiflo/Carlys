import { type CoachTurn } from '../domain/coach-model.port';
import { type MessageWithProposal } from '../infrastructure/coach.repository';
import { volatileContext } from './coach.prompt';

/** Tours renvoyés au modèle. Au-delà, la compaction serait nécessaire. */
const HISTORY_LIMIT = 20;
const TITLE_MAX_LENGTH = 60;

/**
 * Fonctions pures d'un tour de conversation : ce que le service orchestre
 * sans avoir à le porter lui-même.
 */

/**
 * Historique envoyé au modèle. Le rappel de date est collé au DERNIER message
 * — donc après la césure de cache, jamais dans le préfixe stable.
 */
export function buildHistory(
  previous: readonly MessageWithProposal[],
  content: string,
  now: Date = new Date(),
): CoachTurn[] {
  const turns = previous.slice(-HISTORY_LIMIT).map((message): CoachTurn => ({
    role: message.role === 'USER' ? 'user' : 'assistant',
    content: message.content,
  }));
  return [...turns, { role: 'user', content: `${volatileContext(now)}\n${content}` }];
}

/**
 * La réponse du coach à ce message : celle qui le suit IMMÉDIATEMENT dans le
 * fil (les messages sont ordonnés par date). `undefined` si le tour s'est
 * interrompu avant qu'elle soit archivée — le message suivant, s'il existe,
 * est alors une autre question, jamais sa réponse.
 */
export function assistantReplyTo(
  messages: readonly MessageWithProposal[],
  userMessage: Pick<MessageWithProposal, 'id'>,
): MessageWithProposal | undefined {
  const index = messages.findIndex((message) => message.id === userMessage.id);
  if (index === -1) {
    return undefined;
  }
  const next = messages[index + 1];
  return next?.role === 'ASSISTANT' ? next : undefined;
}

/** Identifiants cités par la proposition, pour n'interroger que ceux-là. */
export function extractExerciseIds(raw: Record<string, unknown>): string[] {
  if (!Array.isArray(raw.items)) {
    return [];
  }
  const ids = new Set<string>();
  for (const entry of raw.items) {
    if (typeof entry === 'object' && entry !== null) {
      const id = (entry as Record<string, unknown>).exerciseId;
      if (typeof id === 'string') {
        ids.add(id);
      }
    }
  }
  return [...ids];
}

/** Titre du fil : la première question, tronquée. */
export function titleFrom(content: string): string {
  const trimmed = content.trim();
  return trimmed.length <= TITLE_MAX_LENGTH
    ? trimmed
    : `${trimmed.slice(0, TITLE_MAX_LENGTH - 1)}…`;
}

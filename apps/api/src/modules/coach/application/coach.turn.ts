import { type CoachTurn } from '../domain/coach-model.port';
import { type MessageWithProposal } from '../infrastructure/coach.repository';
import { volatileContext } from './coach.prompt';

const TITLE_MAX_LENGTH = 60;

/**
 * Fonctions pures d'un tour de conversation : ce que le service orchestre
 * sans avoir à le porter lui-même.
 */

/**
 * Historique envoyé au modèle : les messages que la mémoire n'a pas encore
 * résumés (`summarizedThrough`), `limit` au plus (`COACH_HISTORY_MESSAGES`).
 * Ce début ne bouge qu'avec le résumé (voir `memoryKeep`) : d'un tour à
 * l'autre, le texte envoyé PROLONGE le précédent, et Ollama ne relit que la
 * fin. Le plafond reprend la main si la mémoire prend du retard.
 * Le rappel de date est collé au DERNIER message — donc après la césure de
 * cache, jamais dans le préfixe stable.
 */
export function buildHistory(
  previous: readonly MessageWithProposal[],
  content: string,
  limit: number,
  summarizedThrough: Date | null = null,
  now: Date = new Date(),
): CoachTurn[] {
  const unsummarized =
    summarizedThrough === null
      ? previous
      : previous.filter((message) => message.createdAt > summarizedThrough);
  const turns = unsummarized.slice(-limit).map((message): CoachTurn => ({
    role: message.role === 'USER' ? 'user' : 'assistant',
    content: message.content,
  }));
  // La fenêtre doit s'OUVRIR sur un tour utilisateur : l'API du modèle
  // refuse un historique qui commence par une réponse, et ce refus arrive
  // après que le quota du jour a été décompté. La parité tombe juste sur un
  // fil bien formé, mais un tour interrompu (la réponse n'a jamais été
  // archivée) laisse un message utilisateur orphelin qui la retourne. On
  // sacrifie au pire un tour d'historique, et l'invariant ne dépend plus de
  // la parité du fil.
  while (turns.length > 0 && turns[0]?.role === 'assistant') {
    turns.shift();
  }
  return [...turns, { role: 'user', content: `${volatileContext(now)}\n${content}` }];
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

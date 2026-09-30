import { type CoachReply } from '@carlys/api-contracts';
import { ConflictException } from '@nestjs/common';
import { type MessageWithProposal } from '../infrastructure/coach.repository';
import { presentMessage } from './coach.presenter';
import { type CoachQuota } from './coach.quota';

/**
 * Rejeu d'un message déjà écrit dans CE fil. Sa réponse archivée s'il en a
 * une : aucun tour consommé, aucun appel au modèle. `null` si le tour
 * précédent s'est interrompu avant la réponse — il reste à le terminer.
 * Un contenu différent sous le même identifiant est une collision : 409,
 * comme les repas et les séances.
 */
export async function replay(
  quota: CoachQuota,
  userId: string,
  stored: MessageWithProposal,
  reply: MessageWithProposal | null,
  content: string,
): Promise<CoachReply | null> {
  if (stored.content !== content) {
    throw new ConflictException('Identifiant de message déjà utilisé.');
  }
  if (reply === null) {
    return null;
  }
  return {
    userMessage: presentMessage(stored),
    assistantMessage: presentMessage(reply),
    remainingToday: await quota.remaining(userId),
  };
}

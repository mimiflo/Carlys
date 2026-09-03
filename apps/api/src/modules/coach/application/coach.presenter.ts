import { type CoachMessage, type CoachSessionProposal } from '@carlys/api-contracts';
import { type MessageWithProposal } from '../infrastructure/coach.repository';

/** Des lignes Prisma aux contrats d'API — jamais de compteur de jetons ni de champ interne. */
export function presentMessage(message: MessageWithProposal): CoachMessage {
  return {
    id: message.id,
    role: message.role,
    content: message.content,
    proposal: message.proposal === null ? null : presentProposal(message.proposal),
    createdAt: message.createdAt.toISOString(),
  };
}

export function presentProposal(
  proposal: NonNullable<MessageWithProposal['proposal']>,
): CoachSessionProposal {
  return {
    id: proposal.id,
    name: proposal.name,
    estimatedMinutes: proposal.estimatedMinutes,
    sourceTemplateId: proposal.sourceTemplateId,
    acceptedSessionId: proposal.acceptedSessionId,
    items: proposal.items.map((item) => ({
      id: item.id,
      exercisePosition: item.exercisePosition,
      exerciseId: item.exerciseId,
      exerciseName: item.exerciseName,
      setPosition: item.setPosition,
      kind: item.kind,
      targetReps: item.targetReps,
      targetWeightKg: item.targetWeightKg === null ? null : Number(item.targetWeightKg),
      restSeconds: item.restSeconds,
    })),
  };
}

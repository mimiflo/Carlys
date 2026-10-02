import { Injectable } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { type CoachComposition, type CoachTurnOutput } from '../domain/coach-model.port';
import { type ConversationWithMessages, CoachRepository } from '../infrastructure/coach.repository';
import { type CoachIntent, type CoachIntentTurn } from './coach-intent';
import { type BaseWorkout, type WorkoutIntent } from './coach-session';
import { fallbackChoice, sessionProposal } from './coach-session-choice';
import { COMPOSE_STEP, CREATE_WORKOUT_STEP } from './coach-steps';
import { CoachWorkoutCreator } from './coach-workout-creator';
import { acceptableSessionProposal } from './coach.proposals';

/** Rien de faisable à proposer : la raison MÉTIER, dite telle quelle. */
const NOTHING_TO_PROPOSE =
  'Je n’ai pas trouvé de quoi composer cette séance. Dis-moi les muscles à travailler et le ' +
  'matériel dont tu disposes, et je te la compose.';

/** Le fil, vu par le résolveur d'intention : rôles, textes, propositions. */
export function intentTurns(
  conversation: ConversationWithMessages,
  messageId: string,
): CoachIntentTurn[] {
  return conversation.messages
    .filter((message) => message.id !== messageId)
    .map((message) => ({
      role: message.role === 'USER' ? 'user' : 'assistant',
      content: message.content,
      proposalId: message.proposal?.id ?? null,
    }));
}

export const isWorkout = (intent: CoachIntent): intent is WorkoutIntent =>
  intent.kind === 'WORKOUT_PROPOSAL_REQUIRED' ||
  intent.kind === 'WORKOUT_MODIFICATION_REQUIRED' ||
  intent.kind === 'WORKOUT_CREATION_REQUIRED';

/** Ce que la boucle d'outils doit faire proposer au modèle qui n'a rien proposé. */
export const requirementOf = (intent: CoachIntent): 'session' | 'program' | undefined =>
  intent.kind === 'PROGRAM' ? 'program' : isWorkout(intent) ? 'session' : undefined;

type Settled = {
  text: string;
  proposal:
    | (NonNullable<Awaited<ReturnType<typeof acceptableSessionProposal>>> & {
        id: string;
        itemIds: string[];
      })
    | null;
  createdTemplateId: string | null;
};

/**
 * Le CONTRAT d'un tour d'action (ADR 0014), appliqué à ce que le modèle a
 * rendu — jamais à ce qu'il dit avoir fait :
 *
 * - une séance EXIGÉE (proposer, modifier, créer) n'est rendue qu'avec une
 *   proposition VALIDÉE (`proposalId`) ; sans elle, le serveur la compose
 *   seul ; sans rien de faisable, la raison métier le dit ;
 * - une CRÉATION n'est dite faite qu'une fois le modèle de séance écrit en
 *   base (`createdTemplateId`).
 */
@Injectable()
export class CoachActions {
  constructor(
    private readonly repository: CoachRepository,
    private readonly creator: CoachWorkoutCreator,
    @InjectPinoLogger(CoachActions.name) private readonly logger: PinoLogger,
  ) {}

  /** La séance à modifier (« fais-la plus courte », « crée-la en 30 min ») : sa proposition, relue. */
  async baseOf(userId: string, intent: CoachIntent): Promise<BaseWorkout | null> {
    const proposalId = 'proposalId' in intent ? intent.proposalId : null;
    return proposalId === null ? null : this.repository.findOwnProposal(userId, proposalId);
  }

  async settle(
    userId: string,
    intent: CoachIntent,
    output: CoachTurnOutput,
    composition: CoachComposition | null,
    turn: { messageId: string; onStep?: (step: string, done: boolean) => void },
  ): Promise<Settled> {
    const { onStep } = turn;
    if (composition !== null) onStep?.(COMPOSE_STEP, true);
    let text = output.text;
    let proposal = await acceptableSessionProposal(output.proposal, this.repository, this.logger);
    if (isWorkout(intent) && proposal === null) {
      if (composition !== null) {
        // Le modèle n'a rien proposé de valide (texte seul, carte rejetée,
        // fournisseur qui ignore `compose`) : le serveur compose.
        const choice = fallbackChoice(composition);
        proposal = await acceptableSessionProposal(
          sessionProposal(choice, composition),
          this.repository,
          this.logger,
        );
        if (proposal !== null) text = choice.message;
      }
      if (proposal === null) text = NOTHING_TO_PROPOSE;
      this.logger.warn(
        { userId, intent: intent.kind, enforced: proposal !== null },
        'Séance exigée, imposée par le serveur',
      );
    }
    // L'identifiant de la carte vient du MESSAGE : rejoué après une panne, le
    // tour retrouve le même, donc la même séance enregistrée — jamais deux.
    const withIds =
      proposal === null
        ? null
        : {
            ...proposal,
            id: uuidFrom(`${turn.messageId}:proposition`),
            itemIds: proposal.items.map(() => randomUUID()),
          };
    if (intent.kind !== 'WORKOUT_CREATION_REQUIRED' || withIds === null) {
      return { text, proposal: withIds, createdTemplateId: null };
    }
    onStep?.(CREATE_WORKOUT_STEP, false);
    const created = await this.creator.save(userId, withIds.id, {
      name: withIds.name,
      estimatedMinutes: withIds.estimatedMinutes,
      sets: withIds.items.map((item, i) => ({ ...item, id: withIds.itemIds[i] ?? randomUUID() })),
    });
    onStep?.(CREATE_WORKOUT_STEP, true);
    return {
      text: created.ok ? `${text}\n\n${savedLine(created.name)}` : `${text}\n\n${created.reason}`,
      proposal: withIds,
      createdTemplateId: created.ok ? created.templateId : null,
    };
  }
}

/** Un UUID stable tiré de `seed` (forme v5 : version et variante posées). */
export function uuidFrom(seed: string): string {
  const hex = createHash('sha256').update(seed).digest('hex');
  const variant = ((Number.parseInt(hex[16] ?? '0', 16) & 0x3) | 0x8).toString(16);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-${variant}${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

/** Dit APRÈS l'écriture en base, jamais avant. */
export const savedLine = (name: string) =>
  `C’est enregistré : « ${name} » t’attend dans tes séances, prête à lancer.`;

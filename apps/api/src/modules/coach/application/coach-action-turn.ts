import { type CoachReply } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { type ConversationWithMessages, CoachRepository } from '../infrastructure/coach.repository';
import { savedLine } from './coach-actions';
import { type CoachIntent } from './coach-intent';
import { CREATE_WORKOUT_STEP, coachSteps } from './coach-steps';
import { CoachWorkoutCreator } from './coach-workout-creator';
import { presentMessage } from './coach.presenter';
import { CoachQuota, CoachQuotaExceededError } from './coach.quota';
import { titleFrom } from './coach.turn';
import { type CoachStream } from './coach-stream';

/** Les intentions servies SANS le modèle : tout est déjà connu. */
export type DirectIntent =
  | Extract<CoachIntent, { kind: 'CLARIFICATION_REQUIRED' }>
  | (Extract<CoachIntent, { kind: 'WORKOUT_CREATION_REQUIRED' }> & {
      proposalId: string;
      request: null;
    });

/** « Ok crée-la » : la carte en vue, telle quelle. « Crée-la en 30 min » la recompose d'abord. */
export const isDirect = (intent: CoachIntent): intent is DirectIntent =>
  intent.kind === 'CLARIFICATION_REQUIRED' ||
  (intent.kind === 'WORKOUT_CREATION_REQUIRED' &&
    intent.proposalId !== null &&
    intent.request === null);

/**
 * « Ok crée-la », « Enregistre ça » : la séance est DÉJÀ proposée, il n'y a
 * rien à écrire pour le modèle — le serveur l'enregistre, et le dit une fois
 * la base écrite. Aucun appel à Qwen : ni file, ni attente, ni « Bien sûr,
 * je te prépare ça » sans rien derrière. Une demande d'action sans objet
 * (« crée-la » sans séance en vue) reçoit UNE question précise.
 *
 * Un tour comme les autres pour le reste : quota, question archivée, réponse
 * archivée et rejouable par son identifiant (coach.service.ts).
 */
@Injectable()
export class CoachActionTurn {
  constructor(
    private readonly repository: CoachRepository,
    private readonly quota: CoachQuota,
    private readonly creator: CoachWorkoutCreator,
    @InjectPinoLogger(CoachActionTurn.name) private readonly logger: PinoLogger,
  ) {}

  async run(
    userId: string,
    conversation: ConversationWithMessages,
    messageId: string,
    content: string,
    intent: DirectIntent,
    stream: CoachStream,
  ): Promise<CoachReply> {
    // Une question de précision ne coûte rien : elle ne compte pas.
    const remaining =
      intent.kind === 'CLARIFICATION_REQUIRED'
        ? await this.quota.remaining(userId)
        : await this.quota.consume(userId, new Date());
    if (remaining === null) throw new CoachQuotaExceededError();
    const userMessage = await this.repository.saveUserMessage(conversation.id, messageId, content);
    if (userMessage === null) throw new NotFoundException('Conversation introuvable.');

    const steps = coachSteps();
    let text = intent.kind === 'CLARIFICATION_REQUIRED' ? intent.question : '';
    let createdTemplateId: string | null = null;
    if (intent.kind === 'WORKOUT_CREATION_REQUIRED') {
      const call = [{ name: CREATE_WORKOUT_STEP }];
      for (const label of steps.add(call)) stream.onStep?.(label, false, 0);
      const created = await this.creator.fromStored(userId, intent.proposalId);
      for (const label of steps.all({ session: true, program: true })) {
        stream.onStep?.(label, true, 0);
      }
      text = created.ok ? savedLine(created.name) : created.reason;
      createdTemplateId = created.ok ? created.templateId : null;
    }
    stream.onText?.(text);
    const assistantMessage = await this.repository.saveAssistantMessage({
      conversationId: conversation.id,
      id: randomUUID(),
      content: text,
      inputTokens: 0,
      outputTokens: 0,
      proposal: null,
      programProposal: null,
      steps: steps.all({ session: true, program: true }),
      thinkingSeconds: null,
      createdTemplateId,
      title: conversation.title ?? titleFrom(content),
    });
    this.logger.info(
      { userId, conversationId: conversation.id, intent: intent.kind, createdTemplateId },
      'Tour d’action du coach',
    );
    return {
      userMessage: presentMessage(userMessage),
      assistantMessage: presentMessage(assistantMessage),
      remainingToday: remaining,
    };
  }
}

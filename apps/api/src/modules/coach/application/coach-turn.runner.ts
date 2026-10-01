import { type CoachReply } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { CoachProviderUnavailableException } from '../domain/coach-model.port';
import {
  type ConversationWithMessages,
  CoachRepository,
  type MessageWithProposal,
} from '../infrastructure/coach.repository';
import { frenchExerciseNames, frenchExerciseNamesStream } from './coach-exercise-names';
import { CoachContextBuilder } from './coach-context.builder';
import { type CoachAdmission } from './coach-admissions';
import { CoachGateway } from './coach-gateway';
import { CoachMemory } from './coach-memory';
import { presentMessage } from './coach.presenter';
import { COACH_SYSTEM_PROMPT } from './coach.prompt';
import { acceptableSessionProposal, collectProgramProposal } from './coach.proposals';
import { CoachQuota, CoachQuotaExceededError } from './coach.quota';
import { COACH_TOOLS } from './coach.tool-definitions';
import { CoachTools } from './coach.tools';
import { titleFrom } from './coach.turn';

/** Même réponse qu'un fil inconnu : ne pas révéler l'existence d'autrui. */
const CONVERSATION_NOT_FOUND = 'Conversation introuvable.';

/** Ce que la route EN FLUX donne au tour : texte, file, annulation. */
export interface CoachStream {
  onText?: (delta: string) => void;
  /** Attentes devant cette demande, à chaque changement. */
  onQueued?: (ahead: number) => void;
  /** Son tour est venu, après avoir attendu. */
  onStarted?: () => void;
  /** Écran fermé, « Arrêter », réseau coupé : la génération s'arrête. */
  signal?: AbortSignal;
}

/**
 * Le tour proprement dit, une fois la place obtenue dans la passerelle :
 * contexte, quota, question écrite, génération, réponse archivée, puis la
 * mémoire rafraîchie en arrière-plan. Extrait de `CoachService`, qui garde
 * l'orchestration (porte, verrou de la question, rejeu, admission).
 */
@Injectable()
export class CoachTurnRunner {
  constructor(
    private readonly repository: CoachRepository,
    private readonly tools: CoachTools,
    private readonly quota: CoachQuota,
    private readonly gateway: CoachGateway,
    private readonly context: CoachContextBuilder,
    private readonly memory: CoachMemory,
    @InjectPinoLogger(CoachTurnRunner.name) private readonly logger: PinoLogger,
  ) {}

  async run(
    userId: string,
    conversation: ConversationWithMessages,
    admission: CoachAdmission,
    content: string,
    stream: CoachStream,
  ): Promise<CoachReply> {
    const conversationId = conversation.id;
    const { messageId } = admission;
    // Le contexte AVANT le compteur : ses lectures se dégradent en silence,
    // aucune ne brûle un tour de quota (voir CoachContextBuilder).
    const context = await this.context.build(userId, conversation, messageId, content);

    // Le compteur et la question passent APRÈS la file, AVANT le modèle :
    // une demande refusée par la file ou annulée en attente n'a rien coûté,
    // et deux envois simultanés ne franchissent jamais le plafond (INCR).
    // `now` est gardé pour rendre le message au même jour.
    let turn: { now: Date; remaining: number; userMessage: MessageWithProposal } | undefined;
    const programs = collectProgramProposal((calls) => this.tools.run(userId, calls));
    // Les noms d'exercices du catalogue, dans le flux comme dans la réponse.
    const names = stream.onText && frenchExerciseNamesStream(stream.onText);
    const output = await this.gateway
      .generate(
        admission,
        {
          stream: stream.onText !== undefined,
          signal: stream.signal,
          onQueued: stream.onQueued,
          onStarted: stream.onStarted,
        },
        async () => {
          const now = new Date();
          const remaining = await this.quota.consume(userId, now);
          if (remaining === null) {
            throw new CoachQuotaExceededError();
          }
          const userMessage = await this.repository.saveUserMessage(
            conversationId,
            messageId,
            content,
          );
          if (userMessage === null) {
            // Course entre la vérification et l'écriture : même refus, rien n'a été écrit.
            throw new NotFoundException(CONVERSATION_NOT_FOUND);
          }
          turn = { now, remaining, userMessage };
          return {
            system: COACH_SYSTEM_PROMPT,
            // Après la césure de cache : le préfixe partagé reste identique
            // pour tous les utilisateurs, briefing ou pas.
            systemPerUser: context.systemPerUser,
            tools: COACH_TOOLS,
            history: context.history,
            runTools: programs.runTools,
            onText: names?.push,
            signal: stream.signal,
          };
        },
      )
      .catch((error: unknown) => {
        if (error instanceof CoachProviderUnavailableException) {
          // « Tour de coach » ne sera pas écrit : les jetons déjà partis le sont ici.
          this.logger.warn(
            { userId, conversationId, ...error.usage, reason: error.message },
            'Tour de coach interrompu',
          );
        }
        // Rien de décompté (refus de la file, annulation en attente) : rien à
        // rendre. Fournisseur tombé sans rien consommer : le message est rendu.
        if (turn === undefined) throw error;
        return this.quota.refundIfUnavailable(userId, turn.now, error);
      });
    if (turn === undefined) {
      // Impossible : `generate` n'appelle le modèle qu'après `prepare`.
      throw new Error('Tour de coach sans question écrite');
    }
    names?.flush();
    const { remaining, userMessage } = turn;

    const proposal = await acceptableSessionProposal(output.proposal, this.repository, this.logger);
    const programProposal = programs.proposal();

    this.logger.info(
      {
        userId,
        conversationId,
        inputTokens: output.usage.inputTokens,
        outputTokens: output.usage.outputTokens,
        cacheReadTokens: output.usage.cacheReadTokens,
        proposed: proposal !== null,
        programProposed: programProposal !== null,
        refused: output.refused,
      },
      'Tour de coach',
    );

    const assistantMessage = await this.repository.saveAssistantMessage({
      conversationId,
      id: randomUUID(),
      content: frenchExerciseNames(output.text),
      inputTokens: output.usage.inputTokens,
      outputTokens: output.usage.outputTokens,
      proposal:
        proposal === null
          ? null
          : {
              ...proposal,
              id: randomUUID(),
              itemIds: proposal.items.map(() => randomUUID()),
            },
      programProposal: programProposal === null ? null : { ...programProposal, id: randomUUID() },
      title: conversation.title ?? titleFrom(content),
    });

    // La mémoire se rafraîchit APRÈS la réponse, et seulement si la file est
    // libre : elle ne retarde jamais personne.
    this.memory.refreshLater(conversationId);

    return {
      userMessage: presentMessage(userMessage),
      assistantMessage: presentMessage(assistantMessage),
      remainingToday: remaining,
    };
  }
}

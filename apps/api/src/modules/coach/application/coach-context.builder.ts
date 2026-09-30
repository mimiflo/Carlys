import { Injectable } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { ProgramsService } from '../../programs/application/programs.service';
import { UsersService } from '../../users/application/users.service';
import { type CoachTurn } from '../domain/coach-model.port';
import { type ConversationWithMessages, CoachRepository } from '../infrastructure/coach.repository';
import { memoryBriefing, trainingBriefing } from './coach-context.prompt';
import { mentorVoiceBriefing } from './coach.prompt';
import { buildHistory } from './coach.turn';

export interface CoachContext {
  /** Bloc par utilisateur, APRÈS la césure de cache : voix, profil, mémoire. */
  systemPerUser: string;
  history: CoachTurn[];
}

/**
 * Le contexte d'un tour, et rien de plus (ADR 0013, point 7).
 *
 * Consignes de Carlys (préfixe commun, caché par Ollama) → voix du mentor,
 * profil d'entraînement condensé, mémoire résumée → derniers messages →
 * question. Les données détaillées (séances, records, repas) restent derrière
 * les outils de lecture : le modèle ne les demande que si la question l'exige.
 *
 * Chaque lecture se DÉGRADE en silence : un incident sur le profil ou la voix
 * ne doit ni brûler un tour de quota, ni empêcher le coach de répondre.
 */
@Injectable()
export class CoachContextBuilder {
  constructor(
    private readonly repository: CoachRepository,
    private readonly users: UsersService,
    private readonly programs: ProgramsService,
    private readonly config: AppConfigService,
  ) {}

  /**
   * Messages à charger pour un tour : la fenêtre, plus UN — le message du tour
   * lui-même peut y figurer (tour interrompu, repris) sans évincer un tour utile.
   */
  get window(): number {
    return this.config.coachGateway.historyMessages + 1;
  }

  async build(
    userId: string,
    conversation: ConversationWithMessages,
    messageId: string,
    content: string,
  ): Promise<CoachContext> {
    const [voice, training] = await Promise.all([
      this.repository.voiceOf(userId).catch(() => ({ carlysProfile: null, mentorStyle: null })),
      this.training(userId).catch(() => ''),
    ]);
    const systemPerUser = [
      mentorVoiceBriefing(voice),
      training,
      memoryBriefing(conversation.summary),
    ]
      .filter((part) => part !== '')
      .join('\n\n');
    // Le message de ce tour arrive en dernier, jamais aussi dans l'historique :
    // s'il y figure déjà (tour interrompu, repris ici), il en est retiré.
    const history = buildHistory(
      conversation.messages.filter((message) => message.id !== messageId),
      content,
      this.config.coachGateway.historyMessages,
    );
    return { systemPerUser, history };
  }

  private async training(userId: string): Promise<string> {
    const [profile, active] = await Promise.all([
      this.users.training(userId),
      this.programs.activeProgramName(userId),
    ]);
    return trainingBriefing(profile, active);
  }
}

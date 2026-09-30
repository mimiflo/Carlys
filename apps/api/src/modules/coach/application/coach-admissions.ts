import { BadRequestException, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AppConfigService } from '../../../config/app-config.service';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { CoachGate } from '../infrastructure/coach-gate';
import { CoachMetrics } from '../infrastructure/coach-metrics';
import { BUSY_MESSAGE } from './coach-gateway';
import { CoachQuota } from './coach.quota';

/** Une place obtenue dans la passerelle, à rendre quoi qu'il arrive. */
export interface CoachAdmission {
  requestId: string;
  userId: string;
  conversationId: string;
  messageId: string;
  release: () => Promise<void>;
}

/**
 * L'entrée de la passerelle (ADR 0013) : refuser TÔT et sans rien consommer —
 * taille du message, rythme par minute, une génération par personne, file
 * pleine. Toujours sur l'identité Carlys, jamais l'adresse IP. Ce qui passe
 * reçoit une place dans la file partagée, à rendre par `release`.
 */
@Injectable()
export class CoachAdmissions {
  constructor(
    private readonly gate: CoachGate,
    private readonly quota: CoachQuota,
    private readonly metrics: CoachMetrics,
    private readonly config: AppConfigService,
  ) {}

  async admit(
    userId: string,
    conversationId: string,
    messageId: string,
    content: string,
  ): Promise<CoachAdmission> {
    const { maxMessageChars } = this.config.coachGateway;
    if (content.length > maxMessageChars) {
      throw new BadRequestException(`Ton message dépasse ${maxMessageChars} caractères.`);
    }
    if (!(await this.quota.withinRate(userId))) {
      throw new HttpException(
        'Tu envoies trop de messages d’un coup. Attends une minute.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    const requestId = randomUUID();
    const entry = await this.gate.enter(requestId, userId);
    if (entry === 'user_busy') {
      throw new HttpException(
        'Le coach te répond déjà. Attends sa réponse ou arrête-la.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    if (entry === 'busy') {
      this.metrics.requests.inc({ outcome: 'busy' });
      throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
    }
    return {
      requestId,
      userId,
      conversationId,
      messageId,
      release: () => this.gate.leave(requestId, userId),
    };
  }
}

import { Injectable, type OnModuleDestroy } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { TravauxEnVol } from '../../../common/async/travaux-en-vol';
import { AppConfigService } from '../../../config/app-config.service';
import { COACH_GAVE_UP_TEXT } from '../domain/coach-model.port';
import { RedisService } from '../../../infrastructure/cache/redis.service';
import { CoachRepository } from '../infrastructure/coach.repository';
import { COACH_SUMMARY_PROMPT, summaryRequest } from './coach-context.prompt';
import { CoachGateway } from './coach-gateway';

/**
 * Messages que le résumé laisse à l'historique : la moitié la plus récente
 * de la fenêtre. Le résumé n'est réécrit que quand les messages non résumés
 * DÉPASSENT la fenêtre, et il en absorbe alors la moitié la plus ancienne :
 * l'historique avance par paliers, une fois tous les `limit / 2` messages,
 * au lieu de glisser de deux messages à chaque tour (`buildHistory`). Une
 * fenêtre qui glisse change le début du texte envoyé, et Ollama relisait
 * tout l'historique à chaque tour : ≈ 1 470 jetons, ≈ 45 s sur processeur,
 * contre ≈ 350 en moyenne par paliers (mesuré le 1er octobre 2026).
 */
export function memoryKeep(limit: number): number {
  return Math.ceil(limit / 2);
}
/** Messages fondus dans la mémoire par passe : un prompt borné. */
const MEMORY_BATCH_MAX = 30;
/** Une mémoire reste courte : elle est relue à chaque tour. */
const SUMMARY_MAX_CHARS = 1_500;
/** ≈ 120 mots demandés : de quoi les écrire, pas davantage. */
const SUMMARY_MAX_OUTPUT_TOKENS = 300;
/** Un résumé ne tient jamais le créneau plus longtemps que ceci. */
const SUMMARY_TIMEOUT_MS = 120_000;
/** Après un échec, la conversation laisse le modèle tranquille un moment. */
const RETRY_AFTER_FAILURE_MS = 600_000;

/**
 * La mémoire d'une conversation (ADR 0013, point 8).
 *
 * Le modèle ne relit que les derniers messages. Ceux qui en sortent sont
 * fondus, par lots, dans un résumé (objectif, préférences, progression,
 * décisions — voir `COACH_SUMMARY_PROMPT`) que le contexte des tours suivants
 * reprend. Écrit APRÈS une réponse, en arrière-plan, et seulement si personne
 * n'attend dans la file : il ne retarde jamais personne. Raté, il réessaiera
 * au tour suivant ; rien ne se perd, les messages restent en base.
 */
@Injectable()
export class CoachMemory implements OnModuleDestroy {
  private readonly inFlight: TravauxEnVol;

  constructor(
    private readonly repository: CoachRepository,
    private readonly gateway: CoachGateway,
    private readonly config: AppConfigService,
    private readonly redis: RedisService,
    @InjectPinoLogger(CoachMemory.name) private readonly logger: PinoLogger,
  ) {
    this.inFlight = new TravauxEnVol('mémoire du coach', logger);
  }

  refreshLater(conversationId: string): void {
    this.inFlight.suivre(this.refresh(conversationId), {
      succes: () => undefined,
      echec: (err) => this.logger.warn({ err, conversationId }, 'Mémoire du coach non rafraîchie'),
    });
  }

  /** `true` si la mémoire a été réécrite. */
  async refresh(conversationId: string): Promise<boolean> {
    const pause = `coach:memory:pause:${conversationId}`;
    if ((await this.redis.getClient().exists(pause)) === 1) return false;
    const written = await this.summarize(conversationId).catch(async (error: unknown) => {
      // Échec (échéance, modèle tombé) : pas de nouvel essai à chaque tour.
      await this.redis.getClient().set(pause, '1', 'PX', RETRY_AFTER_FAILURE_MS);
      throw error;
    });
    return written;
  }

  private async summarize(conversationId: string): Promise<boolean> {
    const limit = this.config.coachGateway.historyMessages;
    const keep = memoryKeep(limit);
    const backlog = await this.repository.memoryBacklog(conversationId, keep, MEMORY_BATCH_MAX);
    // Jamais une question fondue sans sa réponse : l'historique s'ouvre
    // forcément sur une question, et écarterait la réponse orpheline.
    while (backlog?.messages.at(-1)?.role === 'USER') backlog.messages.pop();
    const last = backlog?.messages.at(-1);
    // Non résumés = `backlog` + `keep` : tant qu'ils tiennent dans la fenêtre,
    // le résumé ne changerait rien à ce que le modèle lit.
    if (backlog === null || last === undefined || backlog.messages.length + keep <= limit) {
      return false;
    }
    const output = await this.gateway.background(
      {
        system: COACH_SUMMARY_PROMPT,
        tools: [],
        history: [{ role: 'user', content: summaryRequest(backlog.summary, backlog.messages) }],
        runTools: () => Promise.resolve([]),
        maxOutputTokens: SUMMARY_MAX_OUTPUT_TOKENS,
      },
      SUMMARY_TIMEOUT_MS,
    );
    const summary = output?.text.trim() ?? '';
    if (output === null) {
      // Pas de créneau libre, ou cédé à une personne : ce n'est pas un échec.
      return false;
    }
    if (output.refused || summary === '' || summary === COACH_GAVE_UP_TEXT) {
      throw new Error('Résumé de mémoire vide ou refusé');
    }
    await this.repository.saveSummary(
      conversationId,
      summary.slice(0, SUMMARY_MAX_CHARS),
      last.createdAt,
    );
    return true;
  }

  async onModuleDestroy(): Promise<void> {
    await this.inFlight.drainer();
  }
}

import { HttpException, HttpStatus, Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { setTimeout as sleep } from 'node:timers/promises';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../../config/app-config.service';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import {
  COACH_MODEL_PORT,
  type CoachModelPort,
  type CoachGeneration,
  CoachProviderUnavailableException,
  type CoachTurnInput,
  type CoachTurnOutput,
} from '../domain/coach-model.port';
import { CoachGate, GATE_LEASE_MS } from '../infrastructure/coach-gate';
import {
  CoachGenerationRepository,
  type GenerationEnd,
} from '../infrastructure/coach-generation.repository';
import { CoachMetrics, type GenerationOutcome } from '../infrastructure/coach-metrics';
import { type CoachAdmission } from './coach-admissions';

/** Tour de garde d'une attente : deux fois par seconde. */
const POLL_MS = 500;
/** Le fond regarde la file toutes les 2 s pour céder sa place. */
const BACKGROUND_WATCH_MS = 2_000;
/** Attente maximale SANS flux : 5 s + les 50 s du tour restent sous nginx. */
const UNSTREAMED_QUEUE_MS = 5_000;
export const BUSY_MESSAGE = 'Le coach est très sollicité en ce moment. Réessaie dans un instant.';

/** Comment une demande attend : flux ou non, annulation, et ce qu'elle apprend. */
export interface CoachWait {
  /** Réponse en flux : l'attente peut durer, la connexion est tenue éveillée. */
  stream: boolean;
  signal?: AbortSignal;
  /** Demandes qui passent avant, à chaque changement. */
  onQueued?: (ahead: number) => void;
  /** Son tour est venu, après avoir attendu. */
  onStarted?: () => void;
}

/**
 * LA porte du modèle (ADR 0013) — l'« AIService » : aucune route ne touche le
 * modèle sans elle.
 *
 * Après l'admission (`CoachAdmissions`), `generate` attend son tour dans la
 * file partagée, appelle le fournisseur derrière `CoachModelPort`, et mesure
 * tout (base, métriques, journaux) ; `background` sert les travaux de fond
 * sans jamais faire attendre personne. L'appelant rend la place dans un
 * `finally`.
 */
@Injectable()
export class CoachGateway {
  constructor(
    private readonly gate: CoachGate,
    private readonly generations: CoachGenerationRepository,
    private readonly metrics: CoachMetrics,
    private readonly config: AppConfigService,
    @Inject(COACH_MODEL_PORT) private readonly model: CoachModelPort,
    @InjectPinoLogger(CoachGateway.name) private readonly logger: PinoLogger,
  ) {}

  /**
   * Attend un créneau, puis génère. `prepare` ne s'exécute qu'une fois le
   * créneau obtenu : c'est là que le quota se décompte et que la question
   * s'écrit — une demande refusée par la file (« très sollicité ») ou
   * annulée en attente n'a rien coûté. Une annulation arrête l'attente comme
   * la génération.
   */
  async generate(
    admission: CoachAdmission,
    wait: CoachWait,
    prepare: () => Promise<CoachTurnInput>,
  ): Promise<CoachTurnOutput> {
    const { requestId, userId, conversationId, messageId } = admission;
    await this.safely(() =>
      this.generations.queued({ id: requestId, userId, conversationId, messageId }),
    );
    const queuedAt = Date.now();
    this.metrics.queued.inc();
    let waited: boolean;
    try {
      waited = await this.waitForSlot(requestId, wait);
    } catch (error) {
      const cancelled = wait.signal?.aborted === true;
      const busy = error instanceof UserFacingUnavailableException;
      await this.end(requestId, cancelled ? 'cancelled' : 'queue_timeout', {
        status: cancelled ? 'CANCELLED' : 'FAILED',
        errorCode: cancelled ? undefined : busy ? 'queue_timeout' : 'gate',
      });
      throw error;
    } finally {
      this.metrics.queued.dec();
    }
    if (waited) wait.onStarted?.();
    const startedAt = Date.now();
    this.metrics.queueWait.observe((startedAt - queuedAt) / 1000);
    await this.safely(() => this.generations.started(requestId, new Date(startedAt)));
    let input: CoachTurnInput;
    try {
      input = await prepare();
    } catch (error) {
      const quota = error instanceof HttpException && error.getStatus() === 429;
      await this.end(requestId, 'failed', {
        status: 'FAILED',
        errorCode: quota ? 'quota' : 'internal',
      });
      throw error;
    }
    return this.run(requestId, input, startedAt);
  }

  /**
   * Travail de fond (résumé de mémoire) : un créneau SEULEMENT si personne
   * n'attend, sur nos workers seulement, et il CÈDE sa place dès qu'une
   * personne arrive dans la file. `null` : rien n'a été lancé, ou il a cédé.
   */
  async background(
    input: Omit<CoachTurnInput, 'signal' | 'timeoutMs'>,
    timeoutMs: number,
  ): Promise<CoachTurnOutput | null> {
    const requestId = randomUUID();
    if (!(await this.gate.tryBackground(requestId))) return null;
    const yieldPlace = new AbortController();
    const watch = setInterval(
      () => void this.yieldIfWaiting(requestId, yieldPlace),
      BACKGROUND_WATCH_MS,
    );
    try {
      const output = await this.model.reply({
        ...input,
        signal: yieldPlace.signal,
        timeoutMs,
      });
      this.metrics.tokens.inc(output.usage.outputTokens);
      return output;
    } catch (error) {
      if (yieldPlace.signal.aborted) return null;
      throw error;
    } finally {
      clearInterval(watch);
      await this.gate.leave(requestId);
    }
  }

  /**
   * Une tâche du modèle HORS conversation (l'analyse d'une photo de repas) :
   * elle entre dans la MÊME file que le coach — une personne, une
   * génération à la fois ; la file pleine dit « très sollicité » —, attend
   * son tour, garde son bail le temps de la tâche, puis rend la place.
   */
  async withSlot<T>(userId: string, signal: AbortSignal, task: () => Promise<T>): Promise<T> {
    const requestId = randomUUID();
    const entry = await this.gate.enter(requestId, userId);
    if (entry === 'user_busy') {
      throw new HttpException(
        'Le coach travaille déjà pour toi. Attends qu’il ait fini.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    if (entry === 'busy') {
      this.metrics.requests.inc({ outcome: 'busy' });
      throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
    }
    try {
      // Aucune connexion à tenir éveillée : la tâche tourne en fond, le
      // client relit son résultat. L'attente a donc toute la patience de la file.
      await this.waitForSlot(requestId, { stream: true, signal });
      const renew = setInterval(() => void this.renewLease(requestId), GATE_LEASE_MS / 3);
      this.metrics.active.inc();
      try {
        return await task();
      } finally {
        clearInterval(renew);
        this.metrics.active.dec();
      }
    } finally {
      await this.gate.leave(requestId, userId);
    }
  }

  /** Quelqu'un attend : le fond s'arrête. Sinon, son bail est prolongé. */
  private async yieldIfWaiting(requestId: string, place: AbortController): Promise<void> {
    try {
      if ((await this.gate.snapshot()).queued > 0) {
        place.abort();
      } else {
        await this.gate.renew(requestId);
      }
    } catch (err) {
      this.logger.warn({ err, requestId }, 'Travail de fond : file illisible');
    }
  }

  private async run(requestId: string, input: CoachTurnInput, startedAt: number) {
    const renew = setInterval(() => void this.renewLease(requestId), GATE_LEASE_MS / 3);
    this.metrics.active.inc();
    let firstToken = false;
    const onText =
      input.onText &&
      ((delta: string) => {
        if (!firstToken) {
          firstToken = true;
          const at = Date.now();
          this.metrics.timeToFirstToken.observe((at - startedAt) / 1000);
          void this.safely(() => this.generations.streaming(requestId, new Date(at)));
        }
        input.onText?.(delta);
      });
    try {
      const output = await this.model.reply({ ...input, onText });
      this.metrics.tokens.inc(output.usage.outputTokens);
      if (output.generation)
        this.recordEnd(requestId, output.generation, output.usage.outputTokens);
      await this.end(requestId, 'completed', {
        status: 'COMPLETED',
        inputTokens: output.usage.inputTokens,
        outputTokens: output.usage.outputTokens,
        model: output.model ?? this.config.coachProvider.model,
        worker: output.worker,
      });
      return output;
    } catch (error) {
      const cancelled = input.signal?.aborted === true;
      const usage = error instanceof CoachProviderUnavailableException ? error.usage : undefined;
      if (error instanceof CoachProviderUnavailableException) {
        this.metrics.finishReasons.inc({ reason: error.end });
        this.logger.warn({ requestId, finishReason: error.end }, 'Coach : génération en échec');
      }
      await this.end(requestId, cancelled ? 'cancelled' : 'failed', {
        status: cancelled ? 'CANCELLED' : 'FAILED',
        errorCode: cancelled ? undefined : errorCodeOf(error),
        inputTokens: usage?.inputTokens,
        outputTokens: usage?.outputTokens,
      });
      throw error;
    } finally {
      clearInterval(renew);
      this.metrics.active.dec();
      this.metrics.duration.observe((Date.now() - startedAt) / 1000);
    }
  }

  /**
   * Comment le tour a fini : chaque fin d'appel, ses reprises, une réponse
   * rendue incomplète. Une ligne de journal par tour, corrélée au `requestId`.
   */
  private recordEnd(requestId: string, generation: CoachGeneration, generatedTokens: number) {
    for (const reason of generation.ends) this.metrics.finishReasons.inc({ reason });
    const succeeded = generation.recovered + generation.unneeded;
    this.metrics.continuations.inc(generation.continuations);
    this.metrics.continuationSuccess.inc(succeeded);
    this.metrics.continuationFailed.inc(generation.continuations - succeeded);
    if (generation.truncated) this.metrics.truncated.inc();
    const log = { requestId, ...generation, generatedTokens, completed: !generation.truncated };
    if (generation.truncated || generation.continuations > 0) {
      this.logger.warn(log, 'Coach : réponse reprise ou incomplète');
    } else {
      this.logger.info(log, 'Coach : fin de génération');
    }
  }

  /** `true` si la demande a dû attendre (le client l'a su par `onQueued`). */
  private async waitForSlot(requestId: string, wait: CoachWait): Promise<boolean> {
    const { queueTimeoutMs } = this.config.coachGateway;
    // Sans flux (anciennes versions de l'appli), rien ne tient la connexion
    // éveillée : l'attente doit laisser au tour ses 50 s sous nginx.
    const patience = wait.stream ? queueTimeoutMs : Math.min(queueTimeoutMs, UNSTREAMED_QUEUE_MS);
    const deadline = Date.now() + patience;
    let told: number | null = null;
    for (;;) {
      if (wait.signal?.aborted === true) {
        throw new CoachProviderUnavailableException('Coach : demande annulée dans la file.', {
          inputTokens: 0,
          outputTokens: 0,
          cacheReadTokens: 0,
        });
      }
      const poll = await this.gate.poll(requestId);
      if ('lost' in poll || (!poll.acquired && Date.now() >= deadline)) {
        this.metrics.requests.inc({ outcome: 'queue_timeout' });
        throw new UserFacingUnavailableException(BUSY_MESSAGE, 'SERVICE_BUSY');
      }
      if (poll.acquired) return told !== null;
      if (poll.ahead !== told) {
        told = poll.ahead;
        wait.onQueued?.(poll.ahead);
      }
      await sleep(POLL_MS, undefined, { signal: wait.signal }).catch(() => undefined);
    }
  }

  /** Un bail perdu (pause de plus d'une minute) remet la file en surcapacité : on le dit. */
  private async renewLease(requestId: string): Promise<void> {
    const kept = await this.gate.renew(requestId).catch((err: unknown) => {
      this.logger.warn({ err, requestId }, 'Bail non renouvelé');
      return true;
    });
    if (!kept) this.logger.warn({ requestId }, 'Bail de génération perdu : créneau déjà repris');
  }

  private async end(requestId: string, outcome: GenerationOutcome, end: GenerationEnd) {
    if (outcome !== 'queue_timeout') this.metrics.requests.inc({ outcome });
    if (outcome === 'cancelled') this.metrics.cancelled.inc();
    if (end.errorCode !== undefined) this.metrics.errors.inc({ reason: end.errorCode });
    await this.safely(() => this.generations.ended(requestId, new Date(), end));
  }

  /** Une mesure ratée ne fait jamais échouer une réponse. */
  private async safely(write: () => Promise<void>): Promise<void> {
    await write().catch((err: unknown) =>
      this.logger.warn({ err }, 'Mesure de génération non écrite'),
    );
  }
}

/** Raison courte pour la base et les métriques — jamais le message. */
function errorCodeOf(error: unknown): string {
  if (error instanceof CoachProviderUnavailableException) {
    return error.end === 'UNKNOWN' ? 'provider' : error.end.toLowerCase();
  }
  return 'internal';
}

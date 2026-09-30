import { Injectable } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { CoachGate } from '../infrastructure/coach-gate';
import {
  CoachGenerationRepository,
  type GenerationStats,
} from '../infrastructure/coach-generation.repository';
import { CoachWorkerPool, type CoachWorkerStatus } from '../infrastructure/coach-worker-pool';

/** Sonde d'un worker : courte, elle ne doit jamais faire attendre l'état de santé. */
const PROBE_TIMEOUT_MS = 2_000;

export interface CoachHealthReport {
  /** Le coach peut-il répondre MAINTENANT ? */
  available: boolean;
  enabled: boolean;
  workers: (Omit<CoachWorkerStatus, 'url'> & { reachable: boolean; latencyMs: number | null })[];
  /** Tous exemplaires de l'API confondus (Redis). */
  queue: { active: number; queued: number; maxConcurrent: number; maxQueued: number };
  lastHour: GenerationStats;
}

/**
 * L'état de la passerelle du coach (ADR 0013) : workers, file, temps moyens,
 * erreurs. Servi par `/internal/ai/health`, protégé comme `/metrics`. Aucune
 * adresse de worker n'en sort — seulement son hôte.
 */
@Injectable()
export class CoachHealth {
  constructor(
    private readonly pool: CoachWorkerPool,
    private readonly gate: CoachGate,
    private readonly generations: CoachGenerationRepository,
    private readonly config: AppConfigService,
  ) {}

  async report(now = new Date()): Promise<CoachHealthReport> {
    const { maxConcurrent, queueMaxSize, cloudFallback } = this.config.coachGateway;
    const [queue, lastHour, workers] = await Promise.all([
      this.gate.snapshot(now.getTime()),
      this.generations.statsSince(new Date(now.getTime() - 3_600_000)),
      Promise.all(
        this.pool
          .status()
          .map(async ({ url, ...worker }) => ({ ...worker, ...(await this.probe(url)) })),
      ),
    ]);
    const enabled = this.config.coachEnabled;
    const cloud = cloudFallback && this.config.anthropicApiKey !== undefined;
    return {
      available:
        enabled &&
        (this.pool.size === 0
          ? this.config.anthropicApiKey !== undefined
          : workers.some((w) => w.healthy && w.reachable) || cloud),
      enabled,
      workers,
      queue: { ...queue, maxConcurrent, maxQueued: queueMaxSize },
      lastHour,
    };
  }

  /** `GET …/models` : la route la plus légère d'une API compatible OpenAI. */
  private async probe(url: string): Promise<{ reachable: boolean; latencyMs: number | null }> {
    const started = Date.now();
    const { apiKey } = this.config.coachProvider;
    try {
      const response = await fetch(`${url.replace(/\/+$/, '')}/models`, {
        signal: AbortSignal.timeout(PROBE_TIMEOUT_MS),
        headers: apiKey === undefined ? {} : { Authorization: `Bearer ${apiKey}` },
      });
      await response.body?.cancel();
      return { reachable: response.ok, latencyMs: Date.now() - started };
    } catch {
      // Injoignable : c'est précisément ce que la sonde doit dire.
      return { reachable: false, latencyMs: null };
    }
  }
}

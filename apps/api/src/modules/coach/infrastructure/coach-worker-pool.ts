import { ServiceUnavailableException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { type CoachWorkerLoad } from './coach-worker-load';

/** Un worker IA : une adresse « …/v1 » compatible OpenAI (Ollama). */
export interface CoachWorker {
  readonly url: string;
  /** L'hôte seul : ce qui part aux journaux, aux métriques et en base. */
  readonly name: string;
  /** Le bail partagé de cette génération, s'il a pu être posé. */
  readonly lease?: string;
}

/** La charge partagée entre exemplaires, et la durée d'un bail. */
export interface SharedWorkerLoad {
  readonly load: Pick<CoachWorkerLoad, 'claim' | 'release' | 'counts'>;
  /** Au-delà de la plus longue génération : un bail n'expire que si son exemplaire est mort. */
  readonly leaseMs: number;
}

interface WorkerState extends CoachWorker {
  active: number;
  /** Écarté jusqu'à cet instant (ms) après une panne ; 0 : sain. */
  downUntil: number;
}

export interface CoachWorkerStatus {
  url: string;
  name: string;
  active: number;
  healthy: boolean;
  downUntil: string | null;
}

/**
 * Les workers IA de l'API (ADR 0013).
 *
 * Choix : le worker SAIN qui a le moins de générations en cours
 * (« least connections »), TOUS exemplaires de l'API confondus (`shared`,
 * des baux dans Redis) ; sans Redis, celles de cet exemplaire. À égalité,
 * l'ordre de la liste. Une panne réseau
 * ou un 5xx l'écarte `cooldownMs` : la tentative suivante part ailleurs, et il
 * revient seul. Si tous sont écartés, on tente celui qui revient le plus tôt :
 * mieux vaut un essai qu'un refus certain.
 *
 * Exception : la suite d'un MÊME tour (outils, occasion d'agir) retourne au
 * worker qui a servi le début (`prefer`), s'il est sain. Lui seul garde la
 * conversation dans son cache : ailleurs, elle se relirait en entier, des
 * dizaines de secondes à 32 jetons/s sur processeur.
 *
 * La mise de côté après une panne reste PAR EXEMPLAIRE : chacun la constate
 * à sa première tentative, et repart aussitôt sur un autre worker.
 */
export class CoachWorkerPool {
  private readonly workers: WorkerState[];

  constructor(
    urls: readonly string[],
    private readonly cooldownMs: number,
    private readonly now: () => number = Date.now,
    private readonly shared?: SharedWorkerLoad,
  ) {
    this.workers = urls.map((url) => ({ url, name: hostOf(url), active: 0, downUntil: 0 }));
  }

  /**
   * Réserve un worker ; `exclude` : ceux qui viennent d'échouer pour ce tour ;
   * `prefer` : le nom de celui qui a servi le début du tour.
   */
  async acquire(exclude: ReadonlySet<string> = new Set(), prefer?: string): Promise<CoachWorker> {
    if (this.workers.length === 0) {
      throw new ServiceUnavailableException('Aucun worker IA configuré.');
    }
    const now = this.now();
    const candidates = this.workers.filter((w) => !exclude.has(w.url));
    const pool = candidates.length > 0 ? candidates : this.workers;
    const healthy = pool.filter((w) => w.downUntil <= now);
    // Tous écartés : le premier revenu seul, mieux vaut un essai qu'un refus.
    const choices =
      healthy.length > 0
        ? healthy
        : [pool.reduce((best, w) => (w.downUntil < best.downUntil ? w : best))];
    const preferred = choices.findIndex((w) => w.name === prefer);

    const lease = randomUUID();
    const rank = this.shared
      ? await this.shared.load.claim(
          choices.map((w) => w.url),
          preferred,
          lease,
          now + this.shared.leaseMs,
          now,
        )
      : null;
    const chosen =
      (rank === null ? undefined : choices[rank]) ??
      choices[preferred] ??
      choices.reduce((best, w) => (w.active < best.active ? w : best));
    chosen.active += 1;
    return { url: chosen.url, name: chosen.name, ...(rank === null ? {} : { lease }) };
  }

  /** Rend le worker ; `failed` : panne du worker (jamais une annulation). Ne lève jamais. */
  release(worker: CoachWorker, failed: boolean): void {
    const state = this.workers.find((w) => w.url === worker.url);
    if (state === undefined) return;
    state.active = Math.max(0, state.active - 1);
    if (failed) {
      state.downUntil = this.now() + this.cooldownMs;
    }
    // Sans attendre Redis : l'état local est à jour, et un bail non rendu
    // expire seul. `release` du partage ne lève jamais.
    if (worker.lease !== undefined) void this.shared?.load.release(worker.url, worker.lease);
  }

  /** `active` : tous exemplaires confondus quand Redis répond, sinon celles de cet exemplaire. */
  async status(): Promise<CoachWorkerStatus[]> {
    const now = this.now();
    const shared = this.shared
      ? await this.shared.load.counts(
          this.workers.map((w) => w.url),
          now,
        )
      : null;
    return this.workers.map((w, index) => ({
      url: w.url,
      name: w.name,
      active: shared?.[index] ?? w.active,
      healthy: w.downUntil <= now,
      downUntil: w.downUntil > now ? new Date(w.downUntil).toISOString() : null,
    }));
  }

  get size(): number {
    return this.workers.length;
  }
}

function hostOf(url: string): string {
  try {
    return new URL(url).host;
  } catch {
    return 'worker';
  }
}

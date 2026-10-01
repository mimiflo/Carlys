import { ServiceUnavailableException } from '@nestjs/common';

/** Un worker IA : une adresse « …/v1 » compatible OpenAI (Ollama). */
export interface CoachWorker {
  readonly url: string;
  /** L'hôte seul : ce qui part aux journaux, aux métriques et en base. */
  readonly name: string;
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
 * Les workers IA d'un exemplaire de l'API (ADR 0013).
 *
 * Choix : le worker SAIN qui a le moins de générations en cours
 * (« least connections ») ; à égalité, l'ordre de la liste. Une panne réseau
 * ou un 5xx l'écarte `cooldownMs` : la tentative suivante part ailleurs, et il
 * revient seul. Si tous sont écartés, on tente celui qui revient le plus tôt :
 * mieux vaut un essai qu'un refus certain.
 *
 * Exception : la suite d'un MÊME tour (outils, occasion d'agir) retourne au
 * worker qui a servi le début (`prefer`), s'il est sain. Lui seul garde la
 * conversation dans son cache : ailleurs, elle se relirait en entier, des
 * dizaines de secondes à 32 jetons/s sur processeur.
 *
 * ponytail: les compteurs sont PAR EXEMPLAIRE de l'API. La file Redis borne
 * déjà le total ; une répartition exacte entre exemplaires ne servira que le
 * jour où plusieurs API partageront plusieurs workers inégaux.
 */
export class CoachWorkerPool {
  private readonly workers: WorkerState[];

  constructor(
    urls: readonly string[],
    private readonly cooldownMs: number,
    private readonly now: () => number = Date.now,
  ) {
    this.workers = urls.map((url) => ({ url, name: hostOf(url), active: 0, downUntil: 0 }));
  }

  /**
   * Réserve un worker ; `exclude` : ceux qui viennent d'échouer pour ce tour ;
   * `prefer` : le nom de celui qui a servi le début du tour.
   */
  acquire(exclude: ReadonlySet<string> = new Set(), prefer?: string): CoachWorker {
    if (this.workers.length === 0) {
      throw new ServiceUnavailableException('Aucun worker IA configuré.');
    }
    const now = this.now();
    const candidates = this.workers.filter((w) => !exclude.has(w.url));
    const pool = candidates.length > 0 ? candidates : this.workers;
    const healthy = pool.filter((w) => w.downUntil <= now);
    const chosen =
      healthy.find((w) => w.name === prefer) ??
      (healthy.length > 0
        ? healthy.reduce((best, w) => (w.active < best.active ? w : best))
        : pool.reduce((best, w) => (w.downUntil < best.downUntil ? w : best)));
    chosen.active += 1;
    return chosen;
  }

  /** Rend le worker ; `failed` : panne du worker (jamais une annulation). */
  release(worker: CoachWorker, failed: boolean): void {
    const state = this.workers.find((w) => w.url === worker.url);
    if (state === undefined) return;
    state.active = Math.max(0, state.active - 1);
    if (failed) {
      state.downUntil = this.now() + this.cooldownMs;
    }
  }

  status(): CoachWorkerStatus[] {
    const now = this.now();
    return this.workers.map((w) => ({
      url: w.url,
      name: w.name,
      active: w.active,
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

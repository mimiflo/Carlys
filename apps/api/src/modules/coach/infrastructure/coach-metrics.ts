import { Injectable } from '@nestjs/common';
import { Counter, Gauge, Histogram } from 'prom-client';
import { MetricsService } from '../../metrics/metrics.service';

/** Secondes : d'une réponse éclair à la génération la plus longue permise. */
const SECONDS = [0.5, 1, 2, 5, 10, 20, 30, 60, 90, 120, 180, 300];

export type GenerationOutcome = 'completed' | 'failed' | 'cancelled' | 'busy' | 'queue_timeout';

/**
 * Les mesures de la passerelle du coach (ADR 0013), sur le registre commun de
 * l'API (`/metrics`, protégé en production).
 *
 * PAR EXEMPLAIRE, comme les mesures HTTP : l'orchestrateur additionne les
 * exemplaires. `ai_requests_active` et `ai_requests_queued` comptent donc
 * les générations et les attentes portées par CE processus.
 */
@Injectable()
export class CoachMetrics {
  readonly requests: Counter<'outcome'>;
  readonly active: Gauge<string>;
  readonly queued: Gauge<string>;
  readonly duration: Histogram<string>;
  readonly queueWait: Histogram<string>;
  readonly timeToFirstToken: Histogram<string>;
  readonly tokens: Counter<string>;
  readonly errors: Counter<'reason'>;
  readonly cancelled: Counter<string>;
  readonly finishReasons: Counter<'reason'>;
  readonly continuations: Counter<string>;
  readonly continuationSuccess: Counter<string>;
  readonly continuationFailed: Counter<string>;
  readonly truncated: Counter<string>;

  constructor(metrics: MetricsService) {
    const registers = [metrics.registry];
    const name = (suffix: string) => `carlys_api_ai_${suffix}`;
    this.requests = new Counter({
      name: name('requests_total'),
      help: 'Demandes au coach, par issue (completed, failed, cancelled, busy, queue_timeout).',
      labelNames: ['outcome'],
      registers,
    });
    this.active = new Gauge({
      name: name('requests_active'),
      help: 'Générations en cours sur cet exemplaire.',
      registers,
    });
    this.queued = new Gauge({
      name: name('requests_queued'),
      help: 'Demandes en attente d’un créneau sur cet exemplaire.',
      registers,
    });
    this.duration = new Histogram({
      name: name('request_duration_seconds'),
      help: 'Durée d’une génération, file non comprise.',
      buckets: SECONDS,
      registers,
    });
    this.queueWait = new Histogram({
      name: name('queue_wait_seconds'),
      help: 'Attente dans la file avant un créneau.',
      buckets: SECONDS,
      registers,
    });
    this.timeToFirstToken = new Histogram({
      name: name('time_to_first_token_seconds'),
      help: 'Du créneau obtenu au premier morceau de texte.',
      buckets: SECONDS,
      registers,
    });
    this.tokens = new Counter({
      name: name('tokens_generated_total'),
      help: 'Jetons produits par le modèle.',
      registers,
    });
    this.errors = new Counter({
      name: name('errors_total'),
      help: 'Générations en échec, par raison.',
      labelNames: ['reason'],
      registers,
    });
    this.cancelled = new Counter({
      name: name('cancelled_total'),
      help: 'Générations annulées (écran fermé, « Arrêter », coupure).',
      registers,
    });
    this.finishReasons = new Counter({
      name: name('generation_finish_reason_total'),
      help: 'Fins d’appel au modèle, par raison (NORMAL_STOP, MAX_TOKENS, TIMEOUT…).',
      labelNames: ['reason'],
      registers,
    });
    this.continuations = new Counter({
      name: name('continuations_total'),
      help: 'Reprises d’une réponse coupée.',
      registers,
    });
    this.continuationSuccess = new Counter({
      name: name('continuation_success_total'),
      help: 'Reprises qui ont terminé la réponse (ou confirmé, « FIN », qu’elle l’était).',
      registers,
    });
    this.continuationFailed = new Counter({
      name: name('continuation_failed_total'),
      help: 'Reprises qui n’ont pas terminé la réponse.',
      registers,
    });
    this.truncated = new Counter({
      name: name('generation_truncated_total'),
      help: 'Réponses rendues incomplètes, faute de reprise possible.',
      registers,
    });
  }
}

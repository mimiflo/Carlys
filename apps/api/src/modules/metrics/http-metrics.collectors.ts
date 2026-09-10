import { Injectable } from '@nestjs/common';
import { Counter, Gauge, Histogram } from 'prom-client';
import { MetricsService } from './metrics.service';

/**
 * Bornes de l'histogramme de latence, en secondes.
 *
 * Choisies autour de ce que l'orchestrateur doit distinguer : « rapide »
 * (< 100 ms), « acceptable » (< 500 ms), « lent » (< 2 s), « en train de
 * tomber » (au-delà). Des bornes plus fines coûteraient des séries pour
 * répondre à une question que personne ne pose ici.
 */
const LATENCY_BUCKETS = [0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10];

/**
 * Les mesures HTTP du réplica : débit, latence, requêtes en vol.
 *
 * Elles sont PAR PROCESSUS, contrairement à la présence : c'est voulu.
 * L'orchestrateur interroge chaque réplica séparément et fait la somme —
 * ce qui lui donne à la fois le débit global et la répartition entre
 * réplicas, donc de quoi voir qu'un seul d'entre eux encaisse tout.
 */
@Injectable()
export class HttpMetricsCollectors {
  private readonly requests: Counter<'method' | 'route' | 'status'>;
  private readonly duration: Histogram<'method' | 'route' | 'status'>;
  private readonly inFlight: Gauge<string>;

  constructor(metrics: MetricsService) {
    const registers = [metrics.registry];
    this.requests = new Counter({
      name: 'carlys_api_http_requests_total',
      help: 'Requêtes HTTP servies, par méthode, route et code de statut.',
      labelNames: ['method', 'route', 'status'],
      registers,
    });
    this.duration = new Histogram({
      name: 'carlys_api_http_request_duration_seconds',
      help: 'Durée des requêtes HTTP, en secondes.',
      labelNames: ['method', 'route', 'status'],
      buckets: LATENCY_BUCKETS,
      registers,
    });
    this.inFlight = new Gauge({
      name: 'carlys_api_http_requests_in_flight',
      help: 'Requêtes HTTP commencées et pas encore terminées.',
      registers,
    });
  }

  started(): void {
    this.inFlight.inc();
  }

  /**
   * Une requête vient de se terminer. Appelée depuis `res.on('finish')` ET
   * depuis `res.on('close')` : un client qui raccroche avant la réponse
   * n'émet jamais `finish`, et sans le second évènement la jauge « en vol »
   * ne redescendrait jamais. L'intergiciel garantit un seul appel.
   */
  finished(method: string, route: string, status: number, seconds: number): void {
    this.inFlight.dec();
    const labels = { method, route, status: String(status) };
    this.requests.inc(labels);
    this.duration.observe(labels, seconds);
  }
}

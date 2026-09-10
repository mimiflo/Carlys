import { Injectable } from '@nestjs/common';
import { collectDefaultMetrics, Registry } from 'prom-client';

/**
 * Détient le registre Prometheus de l'API (préfixe carlys_api_) et le rend.
 *
 * Un registre PROPRE, et non le registre global de prom-client : deux
 * applications Nest instanciées dans le même processus — ce que font les tests
 * e2e — se disputeraient sinon les mêmes noms de séries, et la seconde
 * échouerait au démarrage sur un doublon d'enregistrement.
 *
 * Les collecteurs (HTTP, présence) s'enregistrent sur `registry` ; ce service
 * ne connaît pas leur contenu, il n'en tient que le catalogue.
 */
@Injectable()
export class MetricsService {
  readonly registry: Registry;

  constructor() {
    this.registry = new Registry();
    collectDefaultMetrics({ register: this.registry, prefix: 'carlys_api_' });
  }

  get contentType(): string {
    return this.registry.contentType;
  }

  async metrics(): Promise<string> {
    return this.registry.metrics();
  }
}

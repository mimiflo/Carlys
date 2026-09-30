import { Controller, Get, Res, UseGuards, VERSION_NEUTRAL } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { type Response } from 'express';
import { Public } from '../../../../common/decorators/public.decorator';
import { MetricsAuthGuard } from '../../../metrics/metrics-auth.guard';
import { MetricsService } from '../../../metrics/metrics.service';
import { CoachHealth, type CoachHealthReport } from '../../application/coach-health';

/**
 * État interne de la passerelle IA (ADR 0013), pour l'exploitation — jamais
 * pour l'application. Même protection que `/metrics` : libre hors production,
 * Bearer `METRICS_TOKEN` en production, inexistant sans jeton configuré.
 */
@ApiExcludeController()
@Public()
@SkipThrottle()
@UseGuards(MetricsAuthGuard)
@Controller({ path: 'internal/ai', version: VERSION_NEUTRAL })
export class CoachInternalController {
  constructor(
    private readonly health: CoachHealth,
    private readonly metrics: MetricsService,
  ) {}

  /** Workers, file, temps moyens et erreurs de la dernière heure. */
  @Get('health')
  report(): Promise<CoachHealthReport> {
    return this.health.report();
  }

  /** Les seules séries `carlys_api_ai_*`, au format Prometheus. */
  @Get('metrics')
  async scrape(@Res() response: Response): Promise<void> {
    const all = this.metrics.registry.getMetricsAsArray();
    const names = all
      .map((metric) => metric.name)
      .filter((name) => name.startsWith('carlys_api_ai_'));
    const series = await Promise.all(
      names.map((name) => this.metrics.registry.getSingleMetricAsString(name)),
    );
    response.setHeader('content-type', this.metrics.contentType);
    response.send(`${series.join('\n')}\n`);
  }
}

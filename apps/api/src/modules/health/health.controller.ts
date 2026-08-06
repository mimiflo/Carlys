import { type HealthReport, type LivenessReport } from '@carlys/api-contracts';
import {
  Controller,
  Get,
  HttpStatus,
  Res,
  VERSION_NEUTRAL,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { type Response } from 'express';
import { HealthService } from './health.service';

/**
 * Endpoints techniques hors préfixe /api/v1 :
 *   GET /health        — état complet (200 ou 503)
 *   GET /health/live   — liveness (le processus répond)
 *   GET /health/ready  — readiness (PostgreSQL + Redis joignables)
 */
@ApiTags('health')
@SkipThrottle()
@Controller({ path: 'health', version: VERSION_NEUTRAL })
export class HealthController {
  constructor(private readonly health: HealthService) {}

  @Get()
  @ApiOperation({ summary: 'État de santé complet du service' })
  async check(
    @Res({ passthrough: true }) response: Response,
  ): Promise<HealthReport> {
    const report = await this.health.readiness();
    response.status(
      report.status === 'ok' ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE,
    );
    return report;
  }

  @Get('live')
  @ApiOperation({ summary: 'Liveness — le processus est vivant' })
  live(): LivenessReport {
    return this.health.liveness();
  }

  @Get('ready')
  @ApiOperation({ summary: 'Readiness — dépendances critiques joignables' })
  async ready(
    @Res({ passthrough: true }) response: Response,
  ): Promise<HealthReport> {
    const report = await this.health.readiness();
    response.status(
      report.status === 'ok' ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE,
    );
    return report;
  }
}

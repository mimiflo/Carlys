import { Controller, Get, Res, UseGuards, VERSION_NEUTRAL } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { type Response } from 'express';
import { Public } from '../../common/decorators/public.decorator';
import { MetricsAuthGuard } from './metrics-auth.guard';
import { MetricsService } from './metrics.service';

/** GET /metrics — exposition Prometheus, protégée en production. */
@ApiExcludeController()
@Public()
@SkipThrottle()
@Controller({ path: 'metrics', version: VERSION_NEUTRAL })
export class MetricsController {
  constructor(private readonly metrics: MetricsService) {}

  @Get()
  @UseGuards(MetricsAuthGuard)
  async scrape(@Res() response: Response): Promise<void> {
    response.setHeader('content-type', this.metrics.contentType);
    response.send(await this.metrics.metrics());
  }
}

import { Module } from '@nestjs/common';
import { HttpMetricsCollectors } from './http-metrics.collectors';
import { HttpMetricsMiddleware } from './http-metrics.middleware';
import { MetricsController } from './metrics.controller';
import { MetricsService } from './metrics.service';
import { OnlineUsersCollector } from './online-users.collector';

/**
 * Observabilité de l'API : le registre, les collecteurs, et l'intergiciel qui
 * les alimente.
 *
 * L'intergiciel est FOURNI ici mais POSÉ dans `configure-app.ts`, en tête de
 * la chaîne Express — pas par `MiddlewareConsumer.forRoutes()`. La raison est
 * mesurée, pas théorique : voir le commentaire de `configureApp`.
 */
@Module({
  controllers: [MetricsController],
  providers: [MetricsService, HttpMetricsCollectors, OnlineUsersCollector, HttpMetricsMiddleware],
  exports: [MetricsService, HttpMetricsMiddleware],
})
export class MetricsModule {}

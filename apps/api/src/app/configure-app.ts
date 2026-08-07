import { API_GLOBAL_PREFIX, API_VERSION, MAX_JSON_BODY_SIZE } from '@carlys/shared-config';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import express from 'express';
import helmet from 'helmet';
import { AppConfigService } from '../config/app-config.service';

/**
 * Configuration HTTP partagée entre le bootstrap réel (main.ts) et les tests
 * end-to-end, pour garantir que les tests exercent la même application.
 */
export function configureApp(app: NestExpressApplication): void {
  const config = app.get(AppConfigService);

  app.use(helmet());
  app.enableCors({
    origin: config.corsOrigins,
    credentials: true,
  });

  // Webhooks de paiement : le corps BRUT est indispensable à la vérification
  // de signature — ce middleware doit précéder tout parseur JSON (l'ordre
  // d'enregistrement fait foi, voir main.ts).
  app.use(
    `/${API_GLOBAL_PREFIX}/v${API_VERSION}/webhooks`,
    express.raw({ type: () => true, limit: MAX_JSON_BODY_SIZE }),
  );

  app.setGlobalPrefix(API_GLOBAL_PREFIX, {
    exclude: ['health', 'health/live', 'health/ready', 'metrics'],
  });
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: API_VERSION,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableShutdownHooks();
}

import { MAX_JSON_BODY_SIZE } from '@carlys/shared-config';
import { NestFactory } from '@nestjs/core';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app/app.module';
import { configureApp } from './app/configure-app';
import { AppConfigService } from './config/app-config.service';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
    bodyParser: false,
  });

  const logger = app.get(Logger);
  app.useLogger(logger);

  app.useBodyParser('json', { limit: MAX_JSON_BODY_SIZE });
  app.useBodyParser('urlencoded', {
    extended: true,
    limit: MAX_JSON_BODY_SIZE,
  });

  configureApp(app);

  const config = app.get(AppConfigService);

  if (config.swaggerEnabled) {
    const documentConfig = new DocumentBuilder()
      .setTitle('Carlys API')
      .setDescription(
        'API de la plateforme fitness Carlys — réponses enveloppées { data, meta, requestId }',
      )
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, documentConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(config.port, '0.0.0.0');
  logger.log(
    `Carlys API démarrée sur le port ${config.port} (${config.nodeEnv})`,
  );
}

void bootstrap();

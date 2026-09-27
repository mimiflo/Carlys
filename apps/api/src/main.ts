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

  // configureApp pose TOUT l'ordre des intergiciels, parseurs de corps
  // compris (le brut des webhooks d'abord, puis JSON et urlencoded à 1 Mo) :
  // les tests e2e, qui l'appellent aussi, exercent la même chaîne.
  // `bodyParser: false` empêche Nest d'ajouter les siens.
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
  logger.log(`Carlys API démarrée sur le port ${config.port} (${config.nodeEnv})`);
}

void bootstrap();

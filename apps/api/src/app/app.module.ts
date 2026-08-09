import { REQUEST_ID_HEADER } from '@carlys/shared-config';
import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { randomUUID } from 'node:crypto';
import { type IncomingMessage, type ServerResponse } from 'node:http';
import { LoggerModule } from 'nestjs-pino';
import { AllExceptionsFilter } from '../common/filters/all-exceptions.filter';
import { ResponseEnvelopeInterceptor } from '../common/interceptors/response-envelope.interceptor';
import { AppConfigModule } from '../config/app-config.module';
import { AppConfigService } from '../config/app-config.service';
import { PrismaModule } from '../database/prisma/prisma.module';
import { RedisModule } from '../infrastructure/cache/redis.module';
import { AdminModule } from '../modules/admin/admin.module';
import { MediaModule } from '../modules/media/media.module';
import { AuditModule } from '../modules/audit/audit.module';
import { AuthModule } from '../modules/auth/auth.module';
import { CoachModule } from '../modules/coach/coach.module';
import { ExercisesModule } from '../modules/exercises/exercises.module';
import { HealthModule } from '../modules/health/health.module';
import { MetricsModule } from '../modules/metrics/metrics.module';
import { NutritionModule } from '../modules/nutrition/nutrition.module';
import { ProgressModule } from '../modules/progress/progress.module';
import { SubscriptionsModule } from '../modules/subscriptions/subscriptions.module';
import { UsersModule } from '../modules/users/users.module';
import { WebhooksModule } from '../modules/webhooks/webhooks.module';
import { WorkoutsModule } from '../modules/workout_sessions/workouts.module';
import { WorkoutTemplatesModule } from '../modules/workout_templates/workout-templates.module';

const REQUEST_ID_PATTERN = /^[\w-]{1,64}$/;

function generateRequestId(request: IncomingMessage, response: ServerResponse): string {
  const incoming = request.headers[REQUEST_ID_HEADER];
  const requestId =
    typeof incoming === 'string' && REQUEST_ID_PATTERN.test(incoming) ? incoming : randomUUID();
  response.setHeader(REQUEST_ID_HEADER, requestId);
  return requestId;
}

@Module({
  imports: [
    AppConfigModule,
    LoggerModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => ({
        pinoHttp: {
          level: config.logLevel,
          genReqId: generateRequestId,
          autoLogging: {
            ignore: (request) =>
              request.url?.startsWith('/health') === true ||
              request.url?.startsWith('/metrics') === true,
          },
          redact: {
            paths: ['req.headers.authorization', 'req.headers.cookie'],
            remove: true,
          },
          transport: config.isDevelopment
            ? {
                target: 'pino-pretty',
                options: { singleLine: true, translateTime: 'SYS:HH:MM:ss' },
              }
            : undefined,
        },
      }),
    }),
    ThrottlerModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => ({
        throttlers: [
          {
            ttl: config.rateLimitTtlSeconds * 1_000,
            limit: config.rateLimitMaxRequests,
          },
        ],
      }),
    }),
    PrismaModule,
    RedisModule,
    AuditModule,
    HealthModule,
    MetricsModule,
    UsersModule,
    AuthModule,
    ExercisesModule,
    WorkoutTemplatesModule,
    WorkoutsModule,
    ProgressModule,
    NutritionModule,
    SubscriptionsModule,
    CoachModule,
    WebhooksModule,
    AdminModule,
    MediaModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_INTERCEPTOR, useClass: ResponseEnvelopeInterceptor },
  ],
})
export class AppModule {}

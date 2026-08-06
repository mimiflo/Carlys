import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type Env } from './env.schema';

/**
 * Accès typé et centralisé à la configuration validée.
 * Aucun module ne doit lire `process.env` directement.
 */
@Injectable()
export class AppConfigService {
  constructor(private readonly config: ConfigService<Env, true>) {}

  get nodeEnv(): Env['NODE_ENV'] {
    return this.config.get('NODE_ENV', { infer: true });
  }

  get isProduction(): boolean {
    return this.nodeEnv === 'production';
  }

  get isDevelopment(): boolean {
    return this.nodeEnv === 'development';
  }

  get isTest(): boolean {
    return this.nodeEnv === 'test';
  }

  get port(): number {
    return this.config.get('PORT', { infer: true });
  }

  get databaseUrl(): string {
    return this.config.get('DATABASE_URL', { infer: true });
  }

  get redisUrl(): string {
    return this.config.get('REDIS_URL', { infer: true });
  }

  get corsOrigins(): string[] {
    return this.config
      .get('CORS_ORIGINS', { infer: true })
      .split(',')
      .map((origin) => origin.trim())
      .filter((origin) => origin.length > 0);
  }

  get logLevel(): Env['LOG_LEVEL'] {
    return this.config.get('LOG_LEVEL', { infer: true });
  }

  get rateLimitTtlSeconds(): number {
    return this.config.get('RATE_LIMIT_TTL_SECONDS', { infer: true });
  }

  get rateLimitMaxRequests(): number {
    return this.config.get('RATE_LIMIT_MAX_REQUESTS', { infer: true });
  }

  get swaggerEnabled(): boolean {
    return (
      this.config.get('SWAGGER_ENABLED', { infer: true }) ?? !this.isProduction
    );
  }

  get metricsToken(): string | undefined {
    return this.config.get('METRICS_TOKEN', { infer: true });
  }
}

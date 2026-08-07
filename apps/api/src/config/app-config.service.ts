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
    return this.config.get('SWAGGER_ENABLED', { infer: true }) ?? !this.isProduction;
  }

  get metricsToken(): string | undefined {
    return this.config.get('METRICS_TOKEN', { infer: true });
  }

  // ── Authentification ────────────────────────────────────────────────────

  get jwtAccessSecret(): string {
    return this.config.get('JWT_ACCESS_SECRET', { infer: true });
  }

  get jwtAccessTtlSeconds(): number {
    return this.config.get('JWT_ACCESS_TTL_SECONDS', { infer: true });
  }

  get jwtIssuer(): string {
    return this.config.get('JWT_ISSUER', { infer: true });
  }

  get jwtAudience(): string {
    return this.config.get('JWT_AUDIENCE', { infer: true });
  }

  get refreshTokenTtlDays(): number {
    return this.config.get('REFRESH_TOKEN_TTL_DAYS', { infer: true });
  }

  get maxLoginAttempts(): number {
    return this.config.get('AUTH_MAX_LOGIN_ATTEMPTS', { infer: true });
  }

  get lockoutMinutes(): number {
    return this.config.get('AUTH_LOCKOUT_MINUTES', { infer: true });
  }

  get argon2Options(): { memoryCost: number; timeCost: number; parallelism: number } {
    return {
      memoryCost: this.config.get('ARGON2_MEMORY_KIB', { infer: true }),
      timeCost: this.config.get('ARGON2_TIME_COST', { infer: true }),
      parallelism: this.config.get('ARGON2_PARALLELISM', { infer: true }),
    };
  }

  get emailVerificationTtlHours(): number {
    return this.config.get('EMAIL_VERIFICATION_TTL_HOURS', { infer: true });
  }

  get passwordResetTtlMinutes(): number {
    return this.config.get('PASSWORD_RESET_TTL_MINUTES', { infer: true });
  }

  // ── Abonnements ────────────────────────────────────────────────────────

  get stripeWebhookSecret(): string | undefined {
    return this.config.get('STRIPE_WEBHOOK_SECRET', { infer: true });
  }

  get revenueCatWebhookSecret(): string | undefined {
    return this.config.get('REVENUECAT_WEBHOOK_SECRET', { infer: true });
  }

  // ── E-mails ────────────────────────────────────────────────────────────

  get smtpHost(): string {
    return this.config.get('SMTP_HOST', { infer: true });
  }

  get smtpPort(): number {
    return this.config.get('SMTP_PORT', { infer: true });
  }

  get emailFrom(): string {
    return this.config.get('EMAIL_FROM', { infer: true });
  }

  get publicAppUrl(): string {
    return this.config.get('PUBLIC_APP_URL', { infer: true });
  }
}

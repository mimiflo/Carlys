import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import { type ExecutionContext } from '@nestjs/common';
import { type AppConfigService } from '../../config/app-config.service';
import { MetricsAuthGuard } from './metrics-auth.guard';

function contextWithAuthorization(authorization?: string): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ headers: { authorization } }),
    }),
  } as unknown as ExecutionContext;
}

function configStub(overrides: { isProduction: boolean; metricsToken?: string }): AppConfigService {
  return overrides as unknown as AppConfigService;
}

describe('MetricsAuthGuard', () => {
  it('laisse passer hors production', () => {
    const guard = new MetricsAuthGuard(configStub({ isProduction: false }));

    expect(guard.canActivate(contextWithAuthorization())).toBe(true);
  });

  it('renvoie 404 en production quand aucun jeton n’est configuré', () => {
    const guard = new MetricsAuthGuard(configStub({ isProduction: true }));

    expect(() => guard.canActivate(contextWithAuthorization())).toThrow(NotFoundException);
  });

  it('refuse un jeton invalide en production', () => {
    const guard = new MetricsAuthGuard(
      configStub({
        isProduction: true,
        metricsToken: 'token-metrics-secret-dev',
      }),
    );

    expect(() => guard.canActivate(contextWithAuthorization('Bearer mauvais-jeton'))).toThrow(
      UnauthorizedException,
    );
    expect(() => guard.canActivate(contextWithAuthorization())).toThrow(UnauthorizedException);
  });

  it('accepte le jeton attendu en production', () => {
    const guard = new MetricsAuthGuard(
      configStub({
        isProduction: true,
        metricsToken: 'token-metrics-secret-dev',
      }),
    );

    expect(guard.canActivate(contextWithAuthorization('Bearer token-metrics-secret-dev'))).toBe(
      true,
    );
  });
});

import { type ConfigService } from '@nestjs/config';
import { AppConfigService } from './app-config.service';
import { type Env } from './env.schema';

const configOf = (values: Partial<Record<keyof Env, unknown>>) =>
  new AppConfigService({
    get: (key: keyof Env) => values[key],
  } as unknown as ConfigService<Env, true>);

describe('AppConfigService.swaggerEnabled', () => {
  it('jamais sur un serveur : SWAGGER_ENABLED=true ne publie pas /api/docs en production', () => {
    expect(configOf({ NODE_ENV: 'production', SWAGGER_ENABLED: true }).swaggerEnabled).toBe(false);
  });

  it('en développement : actif par défaut, éteint sur demande', () => {
    expect(configOf({ NODE_ENV: 'development' }).swaggerEnabled).toBe(true);
    expect(configOf({ NODE_ENV: 'development', SWAGGER_ENABLED: false }).swaggerEnabled).toBe(
      false,
    );
  });
});

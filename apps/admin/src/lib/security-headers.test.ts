import { describe, expect, it } from 'vitest';
import nextConfig from '../../next.config';
import { contentSecurityPolicy, securityHeaders } from './security-headers';

/**
 * La console n'envoyait aucun en-tête de sécurité, et `X-Powered-By` en plus.
 * Ces tests lisent la VRAIE configuration de Next, pas seulement le module.
 */

const PRODUCTION = { apiBaseUrl: 'https://api.carlys.app', isDevelopment: false };

function directive(policy: string, name: string): string | undefined {
  return policy
    .split('; ')
    .find((entry) => entry.startsWith(`${name} `))
    ?.slice(name.length + 1);
}

describe('next.config', () => {
  it('ne publie plus X-Powered-By', () => {
    expect(nextConfig.poweredByHeader).toBe(false);
  });

  it('pose les en-têtes de sécurité sur TOUTES les routes', async () => {
    const rules = (await nextConfig.headers?.()) ?? [];
    const all = rules.find((rule) => rule.source === '/:path*');
    const keys = all?.headers.map((header) => header.key) ?? [];

    expect(keys).toEqual(
      expect.arrayContaining([
        'Content-Security-Policy',
        'X-Frame-Options',
        'X-Content-Type-Options',
        'Referrer-Policy',
      ]),
    );
  });
});

describe('contentSecurityPolicy', () => {
  it('interdit d’encadrer la console (clickjacking)', () => {
    expect(directive(contentSecurityPolicy(PRODUCTION), 'frame-ancestors')).toBe("'none'");
  });

  it('ne laisse joindre que la page et l’ORIGINE de l’API', () => {
    const policy = contentSecurityPolicy({
      ...PRODUCTION,
      apiBaseUrl: 'https://api.carlys.app/chemin/',
    });
    expect(directive(policy, 'connect-src')).toBe("'self' https://api.carlys.app");
  });

  it('pas de `eval` ni d’images en clair en production, oui en développement', () => {
    const production = contentSecurityPolicy(PRODUCTION);
    expect(directive(production, 'script-src')).not.toContain('unsafe-eval');
    expect(directive(production, 'img-src')).not.toContain('http:');

    const developpement = contentSecurityPolicy({
      apiBaseUrl: 'http://localhost:3000',
      isDevelopment: true,
    });
    expect(directive(developpement, 'script-src')).toContain("'unsafe-eval'");
    expect(directive(developpement, 'img-src')).toContain('http:');
    expect(directive(developpement, 'connect-src')).toBe("'self' http://localhost:3000");
  });

  // `pnpm build && pnpm start` en local : API et MinIO en http, les photos
  // doivent s'afficher ; un build servi en HTTPS n'en charge jamais en clair.
  it('un build sans TLS accepte les images en http, un build HTTPS non', () => {
    const local = contentSecurityPolicy({
      apiBaseUrl: 'http://localhost:3000',
      isDevelopment: false,
    });
    expect(directive(local, 'img-src')).toContain('http:');
    expect(directive(local, 'script-src')).not.toContain('unsafe-eval');
  });

  it('aucun script externe hors de l’origine, aucun objet embarqué', () => {
    const policy = contentSecurityPolicy(PRODUCTION);
    expect(directive(policy, 'script-src')).toBe("'self' 'unsafe-inline'");
    expect(directive(policy, 'object-src')).toBe("'none'");
    expect(directive(policy, 'base-uri')).toBe("'self'");
  });
});

describe('securityHeaders', () => {
  it('pose nosniff, DENY et aucun référent', () => {
    const headers = Object.fromEntries(
      securityHeaders(PRODUCTION).map((header) => [header.key, header.value]),
    );
    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['X-Frame-Options']).toBe('DENY');
    expect(headers['Referrer-Policy']).toBe('no-referrer');
  });
});

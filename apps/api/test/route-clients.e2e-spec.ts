process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test, type TestingModule } from '@nestjs/testing';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { declaredRoutes, type RouteSignature } from './support/openapi-routes';

const MANIFEST = join(__dirname, '..', '..', '..', 'docs', 'api', 'route-clients.md');

/**
 * Lit les signatures déclarées par le manifeste : la première colonne des
 * lignes de tableau, sous la forme `` `GET /api/v1/…` ``.
 */
function manifestRoutes(): RouteSignature[] {
  const rows = readFileSync(MANIFEST, 'utf8').split('\n');
  const signatures: RouteSignature[] = [];
  for (const row of rows) {
    const match = /^\|\s*`([A-Z]+ \/[^`]*)`\s*\|/.exec(row.trim());
    if (match?.[1] !== undefined) signatures.push(match[1]);
  }
  return signatures;
}

/**
 * LE MANIFESTE ROUTE → CONSOMMATEUR, TENU PAR UN TEST.
 *
 * Rien ne reliait une route de l'API à son appelant : `docs/api/README.md` a
 * pu annoncer « Livré » des routes que personne n'appelait, pendant des mois,
 * sans qu'aucune vérification ne s'en aperçoive. Une route sans client n'est
 * pas forcément un défaut — mais c'est TOUJOURS une décision, et une décision
 * doit être écrite et datée.
 *
 * Le test compare l'ensemble méthode + chemin du document OpenAPI (la même
 * source que `/api/docs`) au manifeste `docs/api/route-clients.md` :
 *  - une route livrée sans ligne de manifeste échoue ;
 *  - une ligne de manifeste qui ne correspond plus à aucune route échoue.
 *
 * Il ne vérifie PAS que le consommateur déclaré appelle vraiment la route :
 * cela reste une lecture humaine, faite au moment où la ligne est écrite.
 */
describe('Manifeste des consommateurs de routes (e2e)', () => {
  let app: INestApplication<App>;
  let declared: RouteSignature[];

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication<NestExpressApplication>();
    declared = declaredRoutes(app);
  });

  afterAll(async () => {
    await app.close();
  });

  it('déclare au moins tout le périmètre connu (garde-fou du lecteur)', () => {
    // Si ce nombre s'effondre, c'est le LECTEUR qui est cassé, pas l'API :
    // un manifeste comparé à une liste vide passerait tout seul.
    expect(declared.length).toBeGreaterThan(50);
    expect(manifestRoutes().length).toBeGreaterThan(50);
  });

  it('chaque route livrée a une ligne dans docs/api/route-clients.md', () => {
    const documented = new Set(manifestRoutes());
    const missing = declared.filter((route) => !documented.has(route));

    expect(missing).toEqual([]);
  });

  it('chaque ligne du manifeste correspond à une route existante', () => {
    const existing = new Set(declared);
    const stale = manifestRoutes().filter((route) => !existing.has(route));

    expect(stale).toEqual([]);
  });

  it('le manifeste ne déclare jamais deux fois la même route', () => {
    const seen = new Set<RouteSignature>();
    const duplicates = manifestRoutes().filter((route) => !seen.add(route));

    expect(duplicates).toEqual([]);
  });
});

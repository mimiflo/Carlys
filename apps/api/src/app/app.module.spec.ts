// Valeurs factices : ce test n'ouvre aucune connexion, il vérifie le CÂBLAGE.
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-de-test-uniquement-32-caracteres-min';

import { Test } from '@nestjs/testing';
import { AppModule } from './app.module';

/**
 * Le graphe d'injection s'assemble-t-il ?
 *
 * Ni `build`, ni `typecheck`, ni les tests unitaires d'un service ne
 * l'exercent : une dépendance non exportée par son module passe la compilation
 * et n'explose qu'au démarrage. Ce test compile le module racine — sans
 * `init()`, donc sans toucher PostgreSQL, Redis ni le stockage objet — pour
 * que ce genre d'erreur coûte quelques secondes, pas un aller-retour de CI.
 */
describe('AppModule', () => {
  it('résout toutes les dépendances, gardes de contrôleurs comprises', async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();

    expect(moduleRef).toBeDefined();
    await moduleRef.close();
  });
});

process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';

import { PrismaClient } from '@prisma/client';

/**
 * Chaque clé étrangère que l'EFFACEMENT D'UN COMPTE traverse a un index qui
 * commence par ses colonnes.
 *
 * POURQUOI. Supprimer une ligne oblige PostgreSQL à retrouver, dans chaque
 * table qui la référence, les lignes à effacer (`CASCADE`), à vider
 * (`SET NULL`) ou à refuser (`RESTRICT`, `NO ACTION`). Sans index sur la
 * colonne référençante, chaque recherche est un balayage de TOUTE la table,
 * répété pour CHAQUE ligne supprimée. La purge des comptes supprimés
 * (`deleted-accounts-purge`) efface un compte d'un seul geste, en
 * transaction : mesuré avant correctif, un compte de 300 séances sur une
 * table de 200 000 records mettait 7,8 s (une recherche complète de
 * `PersonalRecord` par séance), dépassait le délai de la transaction, et le
 * compte n'était jamais effacé. 20 ms avec l'index.
 *
 * Le test lit le catalogue de la VRAIE base migrée : il part de `User`, suit
 * les `ON DELETE CASCADE` de proche en proche, et exige un index pour toute
 * clé qui vise une table atteinte. Une nouvelle relation sans index casse ici,
 * pas un jour dans la purge d'un compte bien rempli.
 */
describe('Effacement d’un compte : clés étrangères indexées (e2e)', () => {
  let prisma: PrismaClient;

  beforeAll(() => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('aucune clé traversée par la cascade depuis User n’est sans index', async () => {
    const sansIndex = await prisma.$queryRaw<Array<{ contrainte: string }>>`
      WITH RECURSIVE atteintes(tbl) AS (
        SELECT '"User"'::regclass
        UNION
        SELECT c.conrelid::regclass
        FROM pg_constraint c JOIN atteintes a ON c.confrelid = a.tbl
        WHERE c.contype = 'f' AND c.confdeltype = 'c'
      )
      SELECT c.conname::text AS contrainte
      FROM pg_constraint c
      WHERE c.contype = 'f'
        AND c.confrelid IN (SELECT tbl FROM atteintes)
        AND NOT EXISTS (
          SELECT 1 FROM pg_index i
          WHERE i.indrelid = c.conrelid
            AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] @> c.conkey
            AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] <@ c.conkey
        )
      ORDER BY 1`;
    expect(sansIndex.map((ligne) => ligne.contrainte)).toEqual([]);
  });
});

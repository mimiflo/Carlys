process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const MIGRATION = join(
  __dirname,
  '..',
  'prisma',
  'migrations',
  '20260927200000_audit_adresses_et_empreintes_nues',
  'migration.sql',
);

/** Les instructions du fichier, commentaires ôtés : une requête préparée n'en prend qu'une. */
function instructions(): string[] {
  return readFileSync(MIGRATION, 'utf8')
    .split('\n')
    .filter((ligne) => !ligne.trimStart().startsWith('--'))
    .join('\n')
    .split(/;\s*$/m)
    .map((instruction) => instruction.trim())
    .filter((instruction) => instruction !== '');
}

/**
 * LA RÉTENTION DE L'AUDIT (décision du 27 septembre 2026) : ce que les
 * anciennes lignes gardaient sans protection en sort. La migration est
 * rejouée ici sur des lignes posées pour l'occasion — elle est idempotente,
 * `prisma migrate deploy` l'a déjà passée sur la base.
 */
describe('Migration : adresses en clair et empreintes nues retirées de l’audit (e2e)', () => {
  let prisma: PrismaClient;
  const action = `e2e.audit-retention.${randomUUID()}`;

  beforeAll(() => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
  });

  afterAll(async () => {
    await prisma.auditLog.deleteMany({ where: { action } });
    await prisma.$disconnect();
  });

  it('adresse en clair → empreinte nulle ; empreinte d’avant le HMAC → nulle ; HMAC et le reste intacts', async () => {
    const ligne = (metadata: object, createdAt = new Date()) =>
      prisma.auditLog.create({ data: { action, metadata, createdAt } });
    const enClair = await ligne({ email: 'lea@exemple.fr' });
    const avantHmac = await ligne({ emailHash: '0123456789ab' }, new Date('2026-09-27T12:00:00Z'));
    const sha256Complet = await ligne({ emailHash: 'a'.repeat(64) });
    const hmac = await ligne({ emailHash: 'abcdef012345' });
    const autre = await ligne({ sessionId: 's-1' });

    for (let passe = 0; passe < 2; passe += 1) {
      for (const instruction of instructions()) {
        await prisma.$executeRawUnsafe(instruction);
      }
    }

    // Relu en SQL, comme la migration écrit. Aucune écriture d'`AuditService`
    // n'est en vol ici : les lignes, ce test les a posées lui-même.
    const relue = async (id: string) =>
      (
        await prisma.$queryRaw<Array<{ metadata: unknown }>>`
          SELECT "metadata" FROM "AuditLog" WHERE "id" = ${id}::uuid`
      )[0]?.metadata;
    expect(await relue(enClair.id)).toEqual({ emailHash: null });
    expect(await relue(avantHmac.id)).toEqual({ emailHash: null });
    expect(await relue(sha256Complet.id)).toEqual({ emailHash: null });
    expect(await relue(hmac.id)).toEqual({ emailHash: 'abcdef012345' });
    expect(await relue(autre.id)).toEqual({ sessionId: 's-1' });
    const lignes = await prisma.$queryRaw<Array<{ metadata: unknown }>>`
      SELECT "metadata" FROM "AuditLog" WHERE "action" = ${action}`;
    expect(lignes).toHaveLength(5);
    expect(lignes.filter((l) => JSON.stringify(l.metadata).includes('@'))).toEqual([]);
  });
});

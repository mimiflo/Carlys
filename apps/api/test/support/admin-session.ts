import {
  type AdminLoginChallenge,
  type AdminLoginResult,
  type ApiSuccessEnvelope,
} from '@carlys/api-contracts';
import { PrismaClient } from '@prisma/client';
import { type Test } from 'supertest';
import { issueAdminTotp } from '../../src/cli/admin-bootstrap';
import { totpCode } from '../../src/modules/admin/application/totp';
import { totpVaultKey } from '../../src/modules/admin/application/totp-vault';

/**
 * Ouvre une session de back-office comme le fait l'admin : le mot de passe,
 * puis le code de l'appli d'authentification (double authentification).
 *
 * Le secret s'émet comme sur un serveur (`issueAdminTotp`, la commande de
 * l'opérateur) à la première session de l'adresse, et se garde pour les
 * suivantes. Chaque connexion d'une même adresse vise le pas de 30 s
 * SUIVANT : un code déjà servi est refusé (anti-rejeu), et la tolérance d'un
 * pas l'accepte encore — deux connexions par adresse et par suite, au plus.
 */
const enrolled = new Map<string, { secret: Buffer; logins: number }>();

const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

export async function issueTestTotp(email: string): Promise<Buffer> {
  const prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
  try {
    return await issueAdminTotp(email, prisma, totpVaultKey(process.env.JWT_ACCESS_SECRET ?? ''));
  } finally {
    await prisma.$disconnect();
  }
}

export async function adminSession(
  server: () => { post(url: string): Test },
  email: string,
  password: string,
): Promise<AdminLoginResult> {
  const known = enrolled.get(email) ?? { secret: await issueTestTotp(email), logins: 0 };
  const challenge = data<AdminLoginChallenge>(
    (await server().post('/api/v1/admin/auth/login').send({ email, password }).expect(200)).body,
  );
  const code = totpCode(known.secret, Math.floor(Date.now() / 1000) + 30 * known.logins);
  enrolled.set(email, { ...known, logins: known.logins + 1 });
  return data<AdminLoginResult>(
    (
      await server()
        .post('/api/v1/admin/auth/totp')
        .send({ challengeToken: challenge.challengeToken, code })
        .expect(200)
    ).body,
  );
}

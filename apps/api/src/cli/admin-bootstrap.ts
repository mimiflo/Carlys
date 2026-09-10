/**
 * `node dist/cli/admin-bootstrap <email> [--role <slug>] [--display-name <nom>] [--reset-password]`
 *
 * Crée un compte d'administration — LE SEUL moyen d'en créer un sur un
 * serveur. L'API n'expose aucune route de création (par choix : un
 * administrateur ne se crée pas depuis l'interface qu'il administre), et le
 * seed de développement, seul autre chemin, ne s'exécute jamais en
 * déploiement. Avant cette commande, la page de connexion du back-office
 * existait sur la recette, et personne ne pouvait la passer.
 *
 * LE MOT DE PASSE ARRIVE PAR L'ENTRÉE STANDARD, jamais en argument ni en
 * variable d'environnement : un argument est lisible dans /proc/<pid>/cmdline
 * par tout utilisateur local pendant toute la durée de la commande, une
 * variable d'environnement dans /proc/<pid>/environ par le même utilisateur.
 * Entrée vide : un mot de passe est engendré et AFFICHÉ UNE SEULE FOIS, sur
 * le terminal de l'opérateur — pas dans un journal.
 *
 * Elle réutilise exactement ce que l'API utilise : `validateEnv` pour lire
 * DATABASE_URL, `PasswordService` pour hacher (mêmes paramètres Argon2id que
 * les connexions), `syncAdminRbac` pour les rôles. Rien n'est recopié.
 */
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import {
  ADMIN_ROLES,
  adminRoleBySlug,
  syncAdminRbac,
} from '../modules/admin/application/admin-rbac';
import { PasswordService } from '../modules/auth/application/password.service';

export const PASSWORD_MIN_LENGTH = 12;

export interface BootstrapArgs {
  readonly email: string;
  readonly role: string;
  readonly displayName: string;
  readonly resetPassword: boolean;
}

export class UsageError extends Error {}

const emailSchema = z.string().trim().toLowerCase().email();

/** Lit les arguments de la ligne de commande (sans `node` ni le script). */
export function parseArgs(argv: readonly string[]): BootstrapArgs {
  const [rawEmail, ...rest] = argv;
  if (rawEmail === undefined || rawEmail.startsWith('--')) {
    throw new UsageError('Adresse e-mail attendue en premier argument.');
  }
  const email = emailSchema.safeParse(rawEmail);
  if (!email.success) {
    throw new UsageError(`Adresse e-mail invalide : « ${rawEmail} ».`);
  }

  let role = 'superadmin';
  let displayName = '';
  let resetPassword = false;
  for (let i = 0; i < rest.length; i += 1) {
    const arg = rest[i];
    switch (arg) {
      case '--role': {
        const value = rest[i + 1];
        if (value === undefined || adminRoleBySlug(value) === undefined) {
          throw new UsageError(
            `--role attend un de : ${ADMIN_ROLES.map((r) => r.slug).join(', ')}.`,
          );
        }
        role = value;
        i += 1;
        break;
      }
      case '--display-name': {
        const value = rest[i + 1];
        if (value === undefined || value.trim() === '') {
          throw new UsageError('--display-name attend un nom non vide.');
        }
        displayName = value.trim();
        i += 1;
        break;
      }
      case '--reset-password':
        resetPassword = true;
        break;
      default:
        throw new UsageError(`Option inconnue : « ${arg ?? ''}».`);
    }
  }
  return {
    email: email.data,
    role,
    displayName: displayName === '' ? (email.data.split('@')[0] ?? email.data) : displayName,
    resetPassword,
  };
}

/** 18 octets aléatoires en base64url : 24 caractères, sans ambiguïté visuelle. */
export function generatePassword(): string {
  return randomBytes(18).toString('base64url');
}

/** Rend un message d'erreur, ou `null` si le mot de passe est acceptable. */
export function validatePassword(password: string): string | null {
  if (password.length < PASSWORD_MIN_LENGTH) {
    return `Mot de passe trop court : ${PASSWORD_MIN_LENGTH} caractères minimum.`;
  }
  return null;
}

/**
 * Le mot de passe fourni par l'entrée standard, ou `null` si elle est vide
 * ou absente. Seule la fin de ligne finale est retirée : un mot de passe peut
 * légitimement contenir des espaces, y compris aux extrémités.
 */
export function readPasswordFromStdin(): string | null {
  if (process.stdin.isTTY) {
    return null;
  }
  let raw: string;
  try {
    raw = readFileSync(0, 'utf8');
  } catch {
    return null;
  }
  const password = raw.replace(/\r?\n$/, '');
  return password === '' ? null : password;
}

function usage(): string {
  return [
    'Usage : node dist/cli/admin-bootstrap <email> [--role <slug>] [--display-name <nom>] [--reset-password]',
    `  rôles : ${ADMIN_ROLES.map((r) => r.slug).join(' | ')}   (défaut : superadmin)`,
    '  Le mot de passe se lit sur l’entrée standard ; vide = engendré et affiché une fois.',
  ].join('\n');
}

export async function bootstrapAdmin(
  args: BootstrapArgs,
  password: string,
  prisma: PrismaClient,
  passwords: PasswordService,
): Promise<{ outcome: 'created' | 'password-reset'; displayName: string }> {
  await syncAdminRbac(prisma);
  const role = await prisma.adminRole.findUniqueOrThrow({ where: { slug: args.role } });
  const passwordHash = await passwords.hash(password);

  const existing = await prisma.adminUser.findUnique({ where: { email: args.email } });
  if (existing !== null && !args.resetPassword) {
    throw new UsageError(
      `${args.email} existe déjà. Pour remplacer son mot de passe : --reset-password.`,
    );
  }

  const admin =
    existing === null
      ? await prisma.adminUser.create({
          data: { email: args.email, displayName: args.displayName, passwordHash },
        })
      : await prisma.adminUser.update({
          where: { id: existing.id },
          data: { passwordHash, status: 'ACTIVE' },
        });

  await prisma.adminUserRole.upsert({
    where: { adminUserId_roleId: { adminUserId: admin.id, roleId: role.id } },
    update: {},
    create: { adminUserId: admin.id, roleId: role.id },
  });
  return {
    outcome: existing === null ? 'created' : 'password-reset',
    displayName: admin.displayName,
  };
}

async function main(argv: readonly string[]): Promise<number> {
  let args: BootstrapArgs;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`${(error as Error).message}\n\n${usage()}\n`);
    return 2;
  }

  let password = readPasswordFromStdin();
  let generated = false;
  if (password === null) {
    password = generatePassword();
    generated = true;
  }
  const invalid = validatePassword(password);
  if (invalid !== null) {
    process.stderr.write(`${invalid}\n`);
    return 2;
  }

  const env: Env = validateEnv(process.env);
  const config = new AppConfigService(new ConfigService<Env, true>(env));
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  try {
    const { outcome, displayName } = await bootstrapAdmin(
      args,
      password,
      prisma,
      new PasswordService(config),
    );
    process.stdout.write(
      [
        outcome === 'created' ? 'Compte créé.' : 'Mot de passe remplacé.',
        `  adresse : ${args.email}`,
        `  rôle    : ${args.role}`,
        // Le nom STOCKÉ : après --reset-password il n'est pas modifié, et
        // afficher celui dérivé de l'adresse laisserait croire le contraire.
        `  nom     : ${displayName}`,
        ...(generated
          ? [
              '',
              '  MOT DE PASSE ENGENDRÉ — affiché UNE SEULE FOIS, à changer après la première connexion :',
              `  ${password}`,
            ]
          : []),
        '',
      ].join('\n'),
    );
    return 0;
  } catch (error) {
    if (error instanceof UsageError) {
      process.stderr.write(`${error.message}\n`);
      return 3;
    }
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  void main(process.argv.slice(2)).then((code) => {
    process.exitCode = code;
  });
}

/**
 * `node dist/cli/admin-bootstrap <email> [--role <slug>] [--display-name <nom>] [--reset-password]`
 * `node dist/cli/admin-bootstrap <email> --reset-2fa` — premier enrôlement
 * d'un compte d'avant la 2FA, téléphone perdu, ou 2FA gelée : un NOUVEAU
 * secret remplace l'ancien. Ni le mot de passe ni les rôles ne bougent.
 *
 * LE SECRET DE DOUBLE AUTHENTIFICATION NAÎT ICI, jamais à la page de
 * connexion : à la création comme au `--reset-2fa`, son QR code s'affiche
 * UNE SEULE FOIS sur le terminal de l'opérateur, à scanner avant la première
 * connexion. Une page qui le montrerait le donnerait au premier qui connaît
 * le mot de passe — un intrus compris, qui verrouillerait le propriétaire.
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
import { toString as qrCode } from 'qrcode';
import { z } from 'zod';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import {
  ADMIN_ROLES,
  adminRoleBySlug,
  syncAdminRbac,
} from '../modules/admin/application/admin-rbac';
import { base32Encode, newTotpSecret, otpauthUri } from '../modules/admin/application/totp';
import { sealTotpSecret, totpVaultKey } from '../modules/admin/application/totp-vault';
import { PasswordService } from '../modules/auth/application/password.service';
import { runCli, UsageError } from './run-cli';

export const PASSWORD_MIN_LENGTH = 12;

export interface BootstrapArgs {
  readonly email: string;
  readonly role: string;
  readonly displayName: string;
  readonly resetPassword: boolean;
  /**
   * `--role` a-t-il été écrit sur la ligne de commande ?
   *
   * La distinction n'est pas cosmétique : `role` porte un DÉFAUT
   * (« superadmin »), et sans ce drapeau une simple réinitialisation de mot
   * de passe appliquait ce défaut au compte visé — promouvant superadmin un
   * admin support dont on voulait seulement changer le mot de passe.
   */
  readonly roleExplicite: boolean;
  /** `--reset-2fa` : émettre un nouveau secret de double authentification, rien d'autre. */
  readonly resetTotp: boolean;
}

export { UsageError };

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
  let roleExplicite = false;
  let displayName = '';
  let resetPassword = false;
  let resetTotp = false;
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
        roleExplicite = true;
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
      case '--reset-2fa':
        resetTotp = true;
        break;
      default:
        throw new UsageError(`Option inconnue : « ${arg ?? ''}».`);
    }
  }
  if (resetTotp && (resetPassword || roleExplicite || displayName !== '')) {
    throw new UsageError(
      '--reset-2fa se lance seul : il ne touche ni au mot de passe ni aux rôles.',
    );
  }
  return {
    email: email.data,
    role,
    displayName: displayName === '' ? (email.data.split('@')[0] ?? email.data) : displayName,
    resetPassword,
    roleExplicite,
    resetTotp,
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
    '        node dist/cli/admin-bootstrap <email> --reset-2fa',
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

  // LES RÔLES NE SE TOUCHENT PAS À LA LÉGÈRE.
  //
  // Deux défauts se combinaient ici. D'abord `--role` porte un défaut,
  // « superadmin » : réinitialiser le mot de passe d'un admin support sans
  // préciser de rôle lui appliquait donc ce défaut. Ensuite l'`upsert`
  // AJOUTAIT le rôle sans retirer les autres : le compte cumulait son rôle
  // d'origine et superadmin. Une opération de dépannage banale — « remets-lui
  // un mot de passe » — promouvait ainsi son destinataire.
  //
  // Désormais : à la CRÉATION, le rôle demandé (ou le défaut) s'applique ; sur
  // un compte EXISTANT, les rôles ne bougent que si `--role` a été écrit
  // explicitement, et ils sont alors REMPLACÉS — c'est ce que « donne-lui ce
  // rôle » veut dire, et le cumul silencieux n'a jamais été demandé.
  if (existing === null || args.roleExplicite) {
    await prisma.$transaction([
      prisma.adminUserRole.deleteMany({
        where: { adminUserId: admin.id, roleId: { not: role.id } },
      }),
      prisma.adminUserRole.upsert({
        where: { adminUserId_roleId: { adminUserId: admin.id, roleId: role.id } },
        update: {},
        create: { adminUserId: admin.id, roleId: role.id },
      }),
    ]);
  }
  return {
    outcome: existing === null ? 'created' : 'password-reset',
    displayName: admin.displayName,
  };
}

/**
 * Émet un NOUVEAU secret de double authentification, chiffré, et le rend
 * pour l'affichage : l'ancien cesse aussitôt de valoir, les codes faux
 * repartent de zéro. L'audit en garde la trace.
 */
export async function issueAdminTotp(
  email: string,
  prisma: PrismaClient,
  vaultKey: Buffer,
): Promise<Buffer> {
  const admin = await prisma.adminUser.findUnique({ where: { email } });
  if (admin === null) throw new UsageError(`Aucun compte d'administration pour ${email}.`);
  const secret = newTotpSecret();
  await prisma.$transaction([
    prisma.adminUser.update({
      where: { id: admin.id },
      data: {
        totpSecret: sealTotpSecret(secret, vaultKey, admin.id),
        totpEnabledAt: null,
        totpLastStep: null,
        totpFailedAttempts: 0,
      },
    }),
    prisma.auditLog.create({
      data: { action: 'admin.totp_issued', actorType: 'SYSTEM', adminUserId: admin.id },
    }),
  ]);
  return secret;
}

/** Le QR code à scanner, et sa clé pour qui ne peut pas scanner. */
export async function totpEnrollmentText(secret: Buffer, email: string): Promise<string> {
  const uri = otpauthUri(secret, email, 'Carlys Admin');
  return [
    '',
    '  DOUBLE AUTHENTIFICATION — affichée UNE SEULE FOIS. Scanne ce QR code avec',
    '  une appli d’authentification (Google Authenticator, Microsoft Authenticator…) :',
    '',
    await qrCode(uri, { type: 'terminal', small: true }),
    `  Impossible de scanner ? Clé à saisir : ${base32Encode(secret).replace(/(.{4})(?=.)/g, '$1 ')}`,
    '  Puis connecte-toi au back-office : mot de passe, puis le code à 6 chiffres.',
    '',
  ].join('\n');
}

async function main(argv: readonly string[]): Promise<number> {
  let args: BootstrapArgs;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`${(error as Error).message}\n\n${usage()}\n`);
    return 2;
  }
  if (args.resetTotp) return issueTotpOnly(args.email);

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
    // Un compte NEUF part avec son secret : il n'a jamais à passer par une
    // page qui l'émettrait. Un mot de passe remplacé ne touche pas la 2FA.
    const enrollment =
      outcome === 'created'
        ? await totpEnrollmentText(
            await issueAdminTotp(args.email, prisma, totpVaultKey(config.jwtAccessSecret)),
            args.email,
          )
        : '';
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
        enrollment,
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

async function issueTotpOnly(email: string): Promise<number> {
  const env: Env = validateEnv(process.env);
  const config = new AppConfigService(new ConfigService<Env, true>(env));
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  try {
    const secret = await issueAdminTotp(email, prisma, totpVaultKey(config.jwtAccessSecret));
    process.stdout.write(
      `Nouveau secret de double authentification pour ${email} — l'ancien ne vaut plus rien.\n${await totpEnrollmentText(secret, email)}\n`,
    );
    return 0;
  } catch (error) {
    process.stderr.write(`${(error as Error).message}\n`);
    return error instanceof UsageError ? 3 : 1;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  runCli(main);
}

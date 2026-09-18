import { ConflictException, Injectable } from '@nestjs/common';
import { Prisma, type User, type UserProfile, UserStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { generateFriendCode } from '../domain/friend-code';
import { tombstoneEmail, tombstoneFriendCode } from '../domain/tombstone';

/**
 * La contrainte d'unicité qui a cédé, d'après `meta.target` de Prisma.
 *
 * Le champ est un tableau de colonnes sur PostgreSQL, mais d'autres
 * connecteurs rendent une chaîne : on accepte les deux plutôt que de parier.
 * Cible inconnue ou absente : on ne prétend rien, et l'appelant décide.
 */
function collidedOn(error: Prisma.PrismaClientKnownRequestError, column: string): boolean {
  const target = error.meta?.target;
  if (Array.isArray(target)) {
    return target.includes(column);
  }
  return typeof target === 'string' && target.includes(column);
}

export type UserWithProfile = User & { profile: UserProfile | null };

export interface CreateUserInput {
  email: string;
  /**
   * Absent pour un compte créé par CONNEXION SOCIALE : pas de ligne
   * credential du tout — la connexion par mot de passe échoue alors
   * naturellement (hash introuvable), sans état « mot de passe vide ».
   */
  passwordHash?: string;
  displayName: string;
  locale?: string;
  timezone?: string;
  /** Adresse déjà vérifiée PAR LE FOURNISSEUR (connexion sociale). */
  emailVerifiedAt?: Date;
}

/** Accès Prisma du domaine utilisateurs — seul point de contact avec la base. */
@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  findActiveByEmail(email: string): Promise<UserWithProfile | null> {
    return this.prisma.user.findFirst({
      where: { email, deletedAt: null },
      include: { profile: true },
    });
  }

  findActiveById(id: string): Promise<UserWithProfile | null> {
    return this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      include: { profile: true },
    });
  }

  emailExists(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  /** Crée l'utilisateur, son profil et sa crédential en une transaction. */
  async create(input: CreateUserInput): Promise<UserWithProfile> {
    // Le code ami est tiré ici, pas en base : l'alphabet est une règle du
    // domaine. Une collision sur 2×10¹¹ combinaisons est invraisemblable ;
    // si elle arrive, on retire.
    //
    // MAIS un P2002 ne vient PAS forcément du code, contrairement à ce qui
    // était écrit ici. L'appelant vérifie l'e-mail AVANT d'appeler `create`,
    // et deux inscriptions simultanées sur la même adresse passent toutes
    // deux cette vérification : la perdante se prend un P2002 sur l'e-mail.
    // La boucle le prenait pour une collision de code, retirait trois codes
    // contre le même mur, puis relançait l'erreur brute — soit un 500 là où
    // la personne attend le 409 qu'elle aurait eu une milliseconde plus tôt.
    // `meta.target` dit quelle contrainte a cédé : on ne retire QUE sur le
    // code ami.
    for (let attempt = 0; ; attempt += 1) {
      try {
        return await this.prisma.user.create({
          data: {
            email: input.email,
            friendCode: generateFriendCode(),
            emailVerifiedAt: input.emailVerifiedAt,
            profile: {
              create: {
                displayName: input.displayName,
                locale: input.locale ?? 'fr',
                timezone: input.timezone ?? 'Europe/Paris',
              },
            },
            credential:
              input.passwordHash === undefined
                ? undefined
                : { create: { passwordHash: input.passwordHash } },
          },
          include: { profile: true },
        });
      } catch (error) {
        if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
          throw error;
        }
        if (collidedOn(error, 'email')) {
          // Course perdue sur l'adresse : même réponse que la vérification
          // préalable de l'appelant, pas une erreur serveur.
          throw new ConflictException('Un compte existe déjà avec cette adresse e-mail.');
        }
        if (!collidedOn(error, 'friendCode') || attempt >= 2) {
          throw error;
        }
      }
    }
  }

  findPasswordHash(userId: string): Promise<string | null> {
    return this.prisma.userCredential
      .findUnique({ where: { userId }, select: { passwordHash: true } })
      .then((credential) => credential?.passwordHash ?? null);
  }

  /**
   * Pose (ou remplace) le mot de passe.
   *
   * `upsert`, jamais `update` : un compte créé par connexion Apple/Google n'a
   * AUCUNE ligne credential, et « mot de passe oublié » est justement le
   * chemin par lequel il s'en donne un. Un `update` y échouait en P2025, que
   * le filtre rendait en 500 — sans consommer le jeton, donc en boucle.
   */
  upsertPasswordHash(userId: string, passwordHash: string): Promise<void> {
    return this.prisma.userCredential
      .upsert({
        where: { userId },
        update: { passwordHash },
        create: { userId, passwordHash },
      })
      .then(() => undefined);
  }

  /**
   * Retire le mot de passe du compte : il ne reste que ses identités externes.
   *
   * Appelé quand une identité sociale est rattachée à un compte dont
   * l'adresse n'avait JAMAIS été vérifiée — le mot de passe qui s'y trouvait
   * a pu être posé par quelqu'un d'autre, avant la personne légitime.
   */
  deleteCredential(userId: string): Promise<void> {
    return this.prisma.userCredential.deleteMany({ where: { userId } }).then(() => undefined);
  }

  markEmailVerified(userId: string): Promise<void> {
    return this.prisma.user
      .update({ where: { id: userId }, data: { emailVerifiedAt: new Date() } })
      .then(() => undefined);
  }

  updateProfile(
    userId: string,
    data: Prisma.UserProfileUpdateWithoutUserInput,
  ): Promise<UserWithProfile> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { profile: { update: data } },
      include: { profile: true },
    });
  }

  /**
   * Profil ET matériel en UNE transaction : un remplacement de liste qui
   * échouerait ne doit pas laisser des scalaires à moitié écrits. La liste
   * est l'état COMPLET (vider = tableau vide), l'écriture est idempotente.
   */
  async updateProfileAndEquipment(
    userId: string,
    data: Prisma.UserProfileUpdateWithoutUserInput,
    equipmentIds: string[],
  ): Promise<UserWithProfile> {
    const [user] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { profile: { update: data } },
        include: { profile: true },
      }),
      this.prisma.userEquipment.deleteMany({ where: { userId } }),
      this.prisma.userEquipment.createMany({
        data: equipmentIds.map((equipmentId) => ({ userId, equipmentId })),
      }),
    ]);
    return user;
  }

  /** Slugs du matériel de l'utilisateur, triés par nom d'équipement. */
  async equipmentSlugs(userId: string): Promise<string[]> {
    const rows = await this.prisma.userEquipment.findMany({
      where: { userId },
      select: { equipment: { select: { slug: true } } },
      orderBy: { equipment: { name: 'asc' } },
    });
    return rows.map((row) => row.equipment.slug);
  }

  /** Résout des slugs vers la taxonomie du catalogue — jamais de texte libre. */
  findEquipmentBySlugs(slugs: string[]): Promise<{ id: string; slug: string }[]> {
    return this.prisma.equipment.findMany({
      where: { slug: { in: slugs } },
      select: { id: true, slug: true },
    });
  }

  /**
   * Suppression de compte, en UNE transaction : le compte passe DELETED et
   * son identité est libérée (adresse et code ami tombaux, nom et profil
   * personnel effacés), ses jetons d'appareil disparaissent. `within` tourne
   * dans la même transaction : c'est la place de ce qui appartient à un autre
   * domaine (la suppression des sessions et de leurs refresh tokens), pour
   * qu'aucun état intermédiaire ne survive à un échec.
   *
   * La ligne reste : l'identifiant est cité par l'audit et par l'historique
   * agrégé (séances, records, journal alimentaire), qui ne portent plus rien
   * qui identifie la personne une fois ces colonnes effacées.
   */
  async deleteAccount(
    userId: string,
    within: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await within(tx);
      await tx.deviceToken.deleteMany({ where: { userId } });
      // Les identités externes partent AVEC le compte. Elles ne portent rien
      // d'historique — seulement un identifiant de fournisseur et une adresse,
      // donnée personnelle que cette suppression prétend justement libérer.
      // Les garder enfermait l'adresse dehors : l'identité survivante pointait
      // sur la tombe, le retour par le fournisseur créait un doublon, puis
      // toute connexion suivante échouait — définitivement.
      await tx.externalIdentity.deleteMany({ where: { userId } });
      await tx.userProfile.updateMany({
        where: { userId },
        data: { displayName: '', birthDate: null, sex: null, heightCm: null },
      });
      await tx.user.update({
        where: { id: userId },
        data: {
          status: UserStatus.DELETED,
          deletedAt: new Date(),
          email: tombstoneEmail(userId),
          friendCode: tombstoneFriendCode(userId),
        },
      });
    });
  }
}

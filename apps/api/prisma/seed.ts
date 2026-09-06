/**
 * Seed de développement Carlys — IDEMPOTENT (upsert par slug / e-mail).
 *
 * ⚠️  Les identifiants créés ici sont STRICTEMENT réservés au développement
 *     et ne doivent JAMAIS exister en production.
 *
 * Contenu : groupes musculaires, équipements, 43 exercices publiés avec les
 * photos qui les illustrent (déposées dans le stockage objet, jamais
 * embarquées dans l'application),
 * plans d'abonnement (gratuit, premium) et deux utilisateurs de
 * démonstration — le compte premium reçoit ses entitlements (droits
 * décidés côté serveur, Étape 6).
 */
import { ADMIN_PERMISSIONS, PREMIUM_ENTITLEMENT_KEYS } from '@carlys/api-contracts';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog';
import { seedExerciseMedia } from './seed-media';
import {
  BillingPeriod,
  ChallengeKind,
  ExerciseDifficulty,
  ExerciseMuscleRole,
  ExerciseType,
  PaymentProvider,
  PrismaClient,
} from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const DEV_USERS = [
  { email: 'dev.gratuit@carlys.local', displayName: 'Dev Gratuit', friendCode: 'DEVFREE2' },
  { email: 'dev.premium@carlys.local', displayName: 'Dev Premium', friendCode: 'DEVPREM2' },
];
const DEV_PASSWORD = 'Carlys-Dev-2026!';

async function seedCatalog(): Promise<void> {
  for (const [index, group] of MUSCLE_GROUPS.entries()) {
    await prisma.muscleGroup.upsert({
      where: { slug: group.slug },
      update: { name: group.name, sortOrder: index },
      create: { slug: group.slug, name: group.name, sortOrder: index },
    });
  }

  for (const equipment of EQUIPMENT) {
    await prisma.equipment.upsert({
      where: { slug: equipment.slug },
      update: { name: equipment.name },
      create: equipment,
    });
  }

  const groups = new Map(
    (await prisma.muscleGroup.findMany()).map((group) => [group.slug, group.id]),
  );
  const equipmentIds = new Map(
    (await prisma.equipment.findMany()).map((equipment) => [equipment.slug, equipment.id]),
  );

  for (const exercise of EXERCISES) {
    const data = {
      name: exercise.name,
      description: exercise.description,
      instructions: exercise.instructions,
      difficulty: exercise.difficulty,
      type: exercise.type,
      isPremium: exercise.isPremium ?? false,
      isPublished: true,
      tags: exercise.tags,
    };
    const { id } = await prisma.exercise.upsert({
      where: { slug: exercise.slug },
      update: data,
      create: { slug: exercise.slug, ...data },
    });

    // Liens muscles/équipements reconstruits à chaque seed (idempotent).
    await prisma.exerciseMuscle.deleteMany({ where: { exerciseId: id } });
    await prisma.exerciseMuscle.createMany({
      data: [
        {
          exerciseId: id,
          muscleGroupId: mustGet(groups, exercise.primary),
          role: ExerciseMuscleRole.PRIMARY,
        },
        ...exercise.secondary.map((slug) => ({
          exerciseId: id,
          muscleGroupId: mustGet(groups, slug),
          role: ExerciseMuscleRole.SECONDARY,
        })),
      ],
    });

    await prisma.exerciseEquipment.deleteMany({ where: { exerciseId: id } });
    await prisma.exerciseEquipment.createMany({
      data: exercise.equipment.map((slug) => ({
        exerciseId: id,
        equipmentId: mustGet(equipmentIds, slug),
      })),
    });
  }
}

/**
 * Plans d'abonnement et correspondances produit chez les fournisseurs.
 * Identifiants produits FACTICES (remplacés par la vraie configuration
 * Stripe/RevenueCat via le tableau de bord de chaque fournisseur).
 */
const SUBSCRIPTION_PLANS = [
  { slug: 'free', name: 'Gratuit' },
  { slug: 'premium', name: 'Premium' },
];

const SUBSCRIPTION_PRODUCTS = [
  {
    plan: 'premium',
    provider: PaymentProvider.STRIPE,
    externalProductId: 'price_carlys_premium_monthly',
    billingPeriod: BillingPeriod.MONTHLY,
  },
  {
    plan: 'premium',
    provider: PaymentProvider.STRIPE,
    externalProductId: 'price_carlys_premium_yearly',
    billingPeriod: BillingPeriod.YEARLY,
  },
  {
    plan: 'premium',
    provider: PaymentProvider.REVENUECAT,
    externalProductId: 'carlys_premium_monthly',
    billingPeriod: BillingPeriod.MONTHLY,
  },
  {
    plan: 'premium',
    provider: PaymentProvider.REVENUECAT,
    externalProductId: 'carlys_premium_yearly',
    billingPeriod: BillingPeriod.YEARLY,
  },
];

async function seedSubscriptionPlans(): Promise<void> {
  for (const plan of SUBSCRIPTION_PLANS) {
    await prisma.subscriptionPlan.upsert({
      where: { slug: plan.slug },
      update: { name: plan.name },
      create: plan,
    });
  }

  const plans = new Map(
    (await prisma.subscriptionPlan.findMany()).map((plan) => [plan.slug, plan.id]),
  );
  for (const product of SUBSCRIPTION_PRODUCTS) {
    await prisma.subscriptionProduct.upsert({
      where: {
        provider_externalProductId: {
          provider: product.provider,
          externalProductId: product.externalProductId,
        },
      },
      update: { billingPeriod: product.billingPeriod },
      create: {
        planId: mustGet(plans, product.plan),
        provider: product.provider,
        externalProductId: product.externalProductId,
        billingPeriod: product.billingPeriod,
      },
    });
  }
}

/**
 * RBAC de l'administration. Le code est la SOURCE DE VÉRITÉ de la liste
 * des permissions (`ADMIN_PERMISSIONS` dans packages/api-contracts).
 */
const ADMIN_ROLES: { slug: string; name: string; permissions: readonly string[] }[] = [
  { slug: 'superadmin', name: 'Super-administrateur', permissions: ADMIN_PERMISSIONS },
  {
    // Les signalements de la communauté sont un travail de support : les lire
    // et les résoudre va avec la lecture des comptes.
    slug: 'support',
    name: 'Support',
    permissions: ['user:read', 'audit:read', 'community:moderate'],
  },
  {
    // Le contenu, c'est aussi les médias : sans `media:write`, ce rôle ne
    // pourrait pas déposer la photo d'un exercice qu'il a le droit de publier.
    slug: 'content-manager',
    name: 'Gestion du contenu',
    permissions: [
      'exercise:read',
      'exercise:publish',
      'exercise:write',
      'media:read',
      'media:write',
    ],
  },
];

const DEV_ADMIN = { email: 'dev.admin@carlys.local', displayName: 'Dev Admin' };
const DEV_ADMIN_PASSWORD = 'Carlys-Admin-2026!';

async function seedAdministration(): Promise<void> {
  for (const permission of ADMIN_PERMISSIONS) {
    const [resource, action] = permission.split(':') as [string, string];
    await prisma.adminPermission.upsert({
      where: { resource_action: { resource, action } },
      update: {},
      create: { resource, action },
    });
  }
  const permissionIds = new Map(
    (await prisma.adminPermission.findMany()).map((permission) => [
      `${permission.resource}:${permission.action}`,
      permission.id,
    ]),
  );

  for (const role of ADMIN_ROLES) {
    const { id } = await prisma.adminRole.upsert({
      where: { slug: role.slug },
      update: { name: role.name },
      create: { slug: role.slug, name: role.name },
    });
    // Liens reconstruits à chaque seed (idempotent).
    await prisma.adminRolePermission.deleteMany({ where: { roleId: id } });
    await prisma.adminRolePermission.createMany({
      data: role.permissions.map((permission) => ({
        roleId: id,
        permissionId: mustGet(permissionIds, permission),
      })),
    });
  }

  const passwordHash = await argon2.hash(DEV_ADMIN_PASSWORD, { type: argon2.argon2id });
  const admin = await prisma.adminUser.upsert({
    where: { email: DEV_ADMIN.email },
    update: {},
    create: { email: DEV_ADMIN.email, displayName: DEV_ADMIN.displayName, passwordHash },
  });
  const superadmin = await prisma.adminRole.findUniqueOrThrow({
    where: { slug: 'superadmin' },
  });
  await prisma.adminUserRole.upsert({
    where: { adminUserId_roleId: { adminUserId: admin.id, roleId: superadmin.id } },
    update: {},
    create: { adminUserId: admin.id, roleId: superadmin.id },
  });
}

async function seedDevUsers(): Promise<void> {
  const passwordHash = await argon2.hash(DEV_PASSWORD, { type: argon2.argon2id });
  for (const user of DEV_USERS) {
    const { id } = await prisma.user.upsert({
      where: { email: user.email },
      update: {},
      create: {
        email: user.email,
        // Codes FIXES (alphabet officiel) : un seed re-joué doit rester
        // idempotent, et un code stable se partage entre postes de dev.
        friendCode: user.friendCode,
        emailVerifiedAt: new Date(),
        profile: { create: { displayName: user.displayName } },
        credential: { create: { passwordHash } },
      },
    });

    // Le compte « premium » reçoit ses droits (attribution manuelle de dev).
    if (user.email === 'dev.premium@carlys.local') {
      for (const key of PREMIUM_ENTITLEMENT_KEYS) {
        await prisma.userEntitlement.upsert({
          where: { userId_entitlementKey: { userId: id, entitlementKey: key } },
          update: { isActive: true, expiresAt: null },
          create: { userId: id, entitlementKey: key, isActive: true },
        });
      }
    }
  }
}

/**
 * Défis communautaires de lancement — collectifs, fenêtres GLISSANTES depuis
 * le seed (un défi expiré au premier lancement ne montrerait rien).
 * Idempotent par slug ; `endsAt` est repoussé à chaque seed de développement.
 */
async function seedCommunityChallenges(): Promise<void> {
  const now = Date.now();
  const inDays = (days: number): Date => new Date(now + days * 24 * 3_600_000);
  const challenges = [
    {
      slug: 'squats-collectifs',
      kind: ChallengeKind.SPORT,
      title: '10 000 squats à plusieurs',
      description:
        'Le groupe additionne ses répétitions de squat jusqu’à 10 000 avant la fin du mois.',
      target: 10_000,
      endsAt: inDays(30),
    },
    {
      slug: 'anatomie-haut-du-corps',
      kind: ChallengeKind.CULTURE,
      title: 'Qui connaît le mieux le haut du corps ?',
      description:
        'Cinq questions d’anatomie par jour pendant une semaine. Le meilleur score gagne.',
      target: 35,
      endsAt: inDays(7),
    },
    {
      slug: 'constance-21-jours',
      kind: ChallengeKind.SPORT,
      title: '21 jours de constance',
      description:
        'Une activité par jour pendant trois semaines, quelle qu’elle soit. La série collective compte.',
      target: 21,
      endsAt: inDays(21),
    },
  ];
  for (const challenge of challenges) {
    const { slug, ...data } = challenge;
    await prisma.communityChallenge.upsert({
      where: { slug },
      create: { slug, ...data },
      update: data,
    });
  }
}

function mustGet(map: Map<string, string>, key: string): string {
  const value = map.get(key);
  if (value === undefined) {
    throw new Error(`Seed incohérent : slug inconnu « ${key} »`);
  }
  return value;
}

async function main(): Promise<void> {
  await seedCatalog();
  await seedExerciseMedia(prisma);
  await seedSubscriptionPlans();
  await seedAdministration();
  await seedDevUsers();
  await seedCommunityChallenges();

  const [exercises, groups, equipment] = await Promise.all([
    prisma.exercise.count(),
    prisma.muscleGroup.count(),
    prisma.equipment.count(),
  ]);
  process.stdout.write(
    `Seed terminé : ${exercises} exercices, ${groups} groupes musculaires, ` +
      `${equipment} équipements.\n` +
      `Comptes de DÉVELOPPEMENT (jamais en production) :\n` +
      DEV_USERS.map((user) => `  - ${user.email} / ${DEV_PASSWORD}\n`).join('') +
      `  - ${DEV_ADMIN.email} / ${DEV_ADMIN_PASSWORD} (admin)\n`,
  );
}

main()
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

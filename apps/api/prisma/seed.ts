/**
 * Seed de développement Carlys — IDEMPOTENT (upsert par slug / e-mail).
 *
 * ⚠️  Les identifiants créés ici sont STRICTEMENT réservés au développement
 *     et ne doivent JAMAIS exister en production.
 *
 * Contenu : le catalogue complet (groupes musculaires, équipements,
 * exercices publiés — projeté par `syncCatalog`, le MÊME code que
 * `dist/cli/catalog-seed` sur un serveur) avec les photos qui l'illustrent
 * (déposées dans le stockage objet, jamais embarquées dans l'application),
 * plans d'abonnement (gratuit, premium) et deux utilisateurs de
 * démonstration — le compte premium reçoit ses entitlements (droits
 * décidés côté serveur, Étape 6).
 */
import { PREMIUM_ENTITLEMENT_KEYS } from '@carlys/api-contracts';
import { syncAdminRbac } from '../src/modules/admin/application/admin-rbac';
import { mustGet, syncCatalog } from '../src/modules/exercises/application/catalog-sync';
import { syncExerciseMedia } from '../src/modules/media/application/catalog-media-sync';
import { BillingPeriod, PaymentProvider, PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const DEV_USERS = [
  { email: 'dev.gratuit@carlys.local', displayName: 'Dev Gratuit', friendCode: 'DEVFREE2' },
  { email: 'dev.premium@carlys.local', displayName: 'Dev Premium', friendCode: 'DEVPREM2' },
];
const DEV_PASSWORD = 'Carlys-Dev-2026!';

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

const DEV_ADMIN = { email: 'dev.admin@carlys.local', displayName: 'Dev Admin' };
const DEV_ADMIN_PASSWORD = 'Carlys-Admin-2026!';

async function seedAdministration(): Promise<void> {
  // Rôles et permissions : le même code que `admin-bootstrap` sur un
  // serveur — le seed n'en est plus l'unique dépositaire.
  await syncAdminRbac(prisma);

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

async function main(): Promise<void> {
  await syncCatalog(prisma);
  await syncExerciseMedia(prisma);
  await seedSubscriptionPlans();
  await seedAdministration();
  await seedDevUsers();
  // Pas de défis ici : le jeu du mois se crée tout seul à la première lecture
  // de GET /community/challenges (catalogue en code, voir
  // modules/community/domain/challenge-catalog.ts).

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

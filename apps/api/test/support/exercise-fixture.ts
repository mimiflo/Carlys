import { type Exercise, type PrismaClient } from '@prisma/client';

/**
 * Exercice de catalogue injecté par une suite e2e — les suites sont
 * AUTONOMES : elles ne dépendent jamais du seed (base CI vierge).
 * Idempotent (upsert) ; chaque suite supprime sa fixture dans son afterAll.
 */
export async function ensureExerciseFixture(
  prisma: PrismaClient,
  slug: string,
  options: { isPremium?: boolean } = {},
): Promise<Exercise> {
  return prisma.exercise.upsert({
    where: { slug },
    update: { isPublished: true },
    create: {
      slug,
      name: `Fixture ${slug}`,
      description: 'Exercice injecté par une suite e2e (jamais le seed).',
      instructions: ['Étape unique'],
      difficulty: 'BEGINNER',
      type: 'STRENGTH',
      isPremium: options.isPremium ?? false,
      tags: ['e2e'],
    },
  });
}

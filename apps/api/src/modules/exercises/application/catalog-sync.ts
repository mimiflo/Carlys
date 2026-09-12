/**
 * Projection du catalogue d'exercices dans la base — IDEMPOTENTE.
 *
 * LE CODE EST LA SOURCE DE VÉRITÉ, pas la base : les données vivent dans
 * `catalog-data.ts`, et cette fonction les projette dans PostgreSQL —
 * groupes musculaires et matériels upsertés par slug, exercices upsertés par
 * slug (publiés d'office), liaisons muscles/équipements reconstruites à
 * chaque passage pour refléter exactement le catalogue. Même motif que
 * `syncAdminRbac` : le seed de développement et la commande serveur
 * (`dist/cli/catalog-seed`) appellent le même code, rien n'est recopié.
 *
 * Cette fonction ne touche NI aux photos (voir `syncExerciseMedia`), NI au
 * cache Redis : un appelant hors du processus API doit purger lui-même le
 * préfixe `catalog:` — sans quoi les listes restent périmées jusqu'à une
 * heure (le TTL des fiches).
 */
import { ExerciseMuscleRole, type Prisma, type PrismaClient } from '@prisma/client';
import { EQUIPMENT, EXERCISES, MUSCLE_GROUPS } from './catalog-data';

/** Ce que la projection a compté — pour que l'appelant puisse le dire. */
export interface CatalogSyncSummary {
  readonly muscleGroups: number;
  readonly equipment: number;
  readonly exercises: number;
}

export function mustGet(map: Map<string, string>, key: string): string {
  const value = map.get(key);
  if (value === undefined) {
    throw new Error(`Catalogue incohérent : slug inconnu « ${key} »`);
  }
  return value;
}

export async function syncCatalog(prisma: PrismaClient): Promise<CatalogSyncSummary> {
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
    // UNE TRANSACTION PAR EXERCICE, et c'est le point important.
    //
    // Les liaisons sont reconstruites par SUPPRESSION puis recréation (voir
    // plus bas) : entre les deux, l'exercice est publié et n'a AUCUN groupe
    // musculaire. Hors transaction, une interruption dans cette fenêtre — un
    // déploiement arrêté, un conteneur tué — fige cet état : l'API sert un
    // exercice sans muscle primaire, et le groupe concerné disparaît des
    // filtres, qui n'exposent que les groupes non vides. Depuis que le
    // chargement est une étape automatique de CHAQUE déploiement
    // (scripts/server/deploy.sh), cette fenêtre s'ouvre bien plus souvent
    // qu'au temps d'une commande tapée à la main.
    //
    // La transaction rend donc chaque exercice ENTIER ou INCHANGÉ. Elle ne
    // couvre volontairement pas tout le catalogue : une interruption laisse
    // alors simplement les exercices restants sur leur version précédente,
    // état cohérent que la relance complète — là où une transaction unique
    // sur 170 exercices tiendrait une connexion et un verrou bien plus
    // longtemps, pour un gain nul.
    await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const { id } = await tx.exercise.upsert({
        where: { slug: exercise.slug },
        update: data,
        create: { slug: exercise.slug, ...data },
      });

      // Liens muscles/équipements reconstruits à chaque passage (idempotent
      // par remplacement) : un muscle retiré d'un exercice dans le code
      // disparaît de la base, il ne survit pas par oubli.
      await tx.exerciseMuscle.deleteMany({ where: { exerciseId: id } });
      await tx.exerciseMuscle.createMany({
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

      await tx.exerciseEquipment.deleteMany({ where: { exerciseId: id } });
      await tx.exerciseEquipment.createMany({
        data: exercise.equipment.map((slug) => ({
          exerciseId: id,
          equipmentId: mustGet(equipmentIds, slug),
        })),
      });
    });
  }

  return {
    muscleGroups: MUSCLE_GROUPS.length,
    equipment: EQUIPMENT.length,
    exercises: EXERCISES.length,
  };
}

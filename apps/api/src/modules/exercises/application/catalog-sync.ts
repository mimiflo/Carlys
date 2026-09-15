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
  /**
   * Exercices présents dans le code mais SUPPRIMÉS par l'administration :
   * leur contenu a été mis à jour, leur publication non. Compté pour que
   * l'exploitant le voie plutôt que de le deviner — un écart durable entre
   * le code et le catalogue servi mérite d'être su.
   */
  readonly keptDeleted: number;
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

  let keptDeleted = 0;

  for (const exercise of EXERCISES) {
    // `isPublished` ne fait PLUS partie du contenu, et c'est tout l'objet du
    // correctif.
    //
    // La suppression d'un exercice par le back-office est DOUCE et repose
    // entièrement sur ce drapeau : `softDeleteExercise` pose `deletedAt` et
    // met `isPublished` à false, et c'est ce dernier qui fait tout le travail
    // — le catalogue mobile, le coach et les modèles filtrent sur lui, aucune
    // de ces requêtes ne connaît `deletedAt`. Un `update` qui forçait
    // `isPublished: true` remettait donc l'exercice en ligne. Et ce n'est pas
    // une commande rare : le chargement du catalogue est l'étape 5/7 de
    // CHAQUE déploiement. Une suppression décidée par l'administration tenait
    // jusqu'au déploiement suivant, sans que rien ne le dise.
    const contenu = {
      name: exercise.name,
      description: exercise.description,
      instructions: exercise.instructions,
      difficulty: exercise.difficulty,
      type: exercise.type,
      isPremium: exercise.isPremium ?? false,
      tags: exercise.tags,
    };
    // UNE TRANSACTION PAR EXERCICE, et c'est le point important.
    //
    // Les liaisons sont reconstruites par SUPPRESSION puis recréation (voir
    // plus bas) : entre les deux, l'exercice est publié et n'a AUCUN groupe
    // musculaire. Hors transaction, une interruption dans cette fenêtre — un
    // déploiement arrêté, un conteneur tué — fige cet état : l'API sert alors
    // un exercice sans muscle primaire, et le groupe concerné sort même des
    // filtres si cet exercice en était l'unique membre publié (la liste des
    // groupes n'expose que les non vides). Depuis que le chargement est une
    // étape automatique de CHAQUE déploiement (scripts/server/deploy.sh),
    // cette fenêtre s'ouvre bien plus souvent qu'au temps d'une commande
    // tapée à la main.
    //
    // La transaction rend donc chaque exercice ENTIER ou INCHANGÉ. Elle ne
    // couvre volontairement pas tout le catalogue : une interruption laisse
    // alors simplement les exercices restants sur leur version précédente,
    // état cohérent que la relance complète — là où une transaction unique
    // sur 170 exercices tiendrait une connexion et un verrou bien plus
    // longtemps, pour un gain nul.
    //
    // `timeout` EXPLICITE : une transaction interactive expire au bout de 5 s
    // par défaut, plafond qui n'existait pas avant et qu'on ne veut pas
    // hériter en silence. Ces cinq écritures se comptent en millisecondes ;
    // les quinze secondes ne servent qu'à absorber une contention passagère
    // avec le back-office, plutôt que d'interrompre un déploiement pour une
    // attente de verrou.
    await prisma.$transaction(
      async (tx: Prisma.TransactionClient) => {
        // Lu DANS la transaction : entre la lecture et l'écriture, un admin
        // pourrait supprimer l'exercice, et la republication reviendrait par
        // la fenêtre.
        const existant = await tx.exercise.findUnique({
          where: { slug: exercise.slug },
          select: { deletedAt: true },
        });
        const supprime = existant !== null && existant.deletedAt !== null;
        if (supprime) {
          keptDeleted += 1;
        }

        const { id } = await tx.exercise.upsert({
          where: { slug: exercise.slug },
          // Sur un exercice supprimé : le contenu se met à jour — il servira
          // si l'administration le restaure — mais la publication reste ce
          // qu'elle a décidé.
          update: supprime ? contenu : { ...contenu, isPublished: true },
          create: { slug: exercise.slug, ...contenu, isPublished: true },
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
      },
      { timeout: 15_000 },
    );
  }

  return {
    muscleGroups: MUSCLE_GROUPS.length,
    equipment: EQUIPMENT.length,
    exercises: EXERCISES.length,
    keptDeleted,
  };
}

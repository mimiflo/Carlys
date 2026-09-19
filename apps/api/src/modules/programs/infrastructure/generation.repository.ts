import { Injectable } from '@nestjs/common';
import { ExerciseDifficulty, ExerciseMuscleRole, type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type PoolExercise } from '../domain/generation/types';

/** Ce que le plafond d'expérience autorise, du plus prudent au plus large. */
const DIFFICULTY_CEILING: Record<string, ExerciseDifficulty[]> = {
  BEGINNER: [ExerciseDifficulty.BEGINNER],
  INTERMEDIATE: [ExerciseDifficulty.BEGINNER, ExerciseDifficulty.INTERMEDIATE],
  ADVANCED: [
    ExerciseDifficulty.BEGINNER,
    ExerciseDifficulty.INTERMEDIATE,
    ExerciseDifficulty.ADVANCED,
  ],
};

const POOL_SELECT = {
  id: true,
  slug: true,
  name: true,
  difficulty: true,
  type: true,
  tags: true,
  muscles: { select: { role: true, muscleGroup: { select: { slug: true } } } },
  equipment: { select: { equipment: { select: { slug: true } } } },
} satisfies Prisma.ExerciseSelect;

type PoolRow = Prisma.ExerciseGetPayload<{ select: typeof POOL_SELECT }>;

function toPoolExercise(row: PoolRow): PoolExercise {
  const primary = row.muscles.find((link) => link.role === ExerciseMuscleRole.PRIMARY);
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    primary: primary?.muscleGroup.slug ?? '',
    secondary: row.muscles
      .filter((link) => link.role !== ExerciseMuscleRole.PRIMARY)
      .map((link) => link.muscleGroup.slug),
    difficulty: row.difficulty,
    type: row.type,
    tags: row.tags,
    equipment: row.equipment.map((link) => link.equipment.slug),
  };
}

/**
 * Le POOL JOUABLE de la génération — et lui seul.
 *
 * Pourquoi une méthode de plus plutôt que `ExercisesRepository.listPage` :
 * celle-ci exprime « contient au moins ce matériel » (`some`), c'est-à-dire
 * une INTERSECTION. Elle proposerait le développé couché à quelqu'un qui n'a
 * qu'un banc. La génération a besoin de l'INCLUSION — « tout le matériel de
 * l'exercice est dans le kit » — qui s'écrit `none: { notIn: kit }`. Elle ne
 * sait pas non plus filtrer par rôle PRIMARY, ni écarter le premium.
 *
 * Et on ne passe PAS par `ExercisesService.list` : son cache Redis est clé
 * sur ses propres filtres, qui ne connaissent ni le rôle ni les droits.
 */
@Injectable()
export class GenerationRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Les exercices réellement jouables : matériel inclus dans le kit,
   * difficulté sous le plafond, premium seulement si le droit est là.
   *
   * L'ordre est TOTAL (`slug` est unique) : jamais l'ordre d'insertion,
   * jamais le plan d'exécution de PostgreSQL. C'est ce qui rend la génération
   * reproductible d'une machine à l'autre.
   */
  async playablePool(
    kitSlugs: string[],
    experience: string,
    premiumAllowed: boolean,
  ): Promise<PoolExercise[]> {
    const rows = await this.prisma.exercise.findMany({
      where: {
        isPublished: true,
        difficulty: { in: DIFFICULTY_CEILING[experience] ?? DIFFICULTY_CEILING.BEGINNER },
        ...(premiumAllowed ? {} : { isPremium: false }),
        // Aucun matériel hors du kit… et au moins un matériel : sans cette
        // seconde clause, un exercice créé depuis l'administration SANS
        // aucun lien passerait le `none` (rien n'est hors du kit) et
        // entrerait dans tous les programmes.
        equipment: { none: { equipment: { slug: { notIn: kitSlugs } } }, some: {} },
        muscles: { some: { role: ExerciseMuscleRole.PRIMARY } },
      },
      select: POOL_SELECT,
      orderBy: { slug: 'asc' },
    });
    return rows.map(toPoolExercise).filter((exercise) => exercise.primary !== '');
  }

  /**
   * Écrit le programme généré ET ses modèles en UNE transaction.
   *
   * Les identifiants sont DÉRIVÉS de `programId` (voir `generator.ts`), donc
   * un rejeu après coupure réécrit les mêmes lignes au lieu d'en créer un
   * second jeu : l'idempotence se prouve par égalité d'identifiants, pas par
   * un journal.
   *
   * Le programme naît INACTIF. L'activer désactiverait le programme en cours
   * dans la même transaction (invariant « un seul actif ») : quelqu'un qui
   * voulait seulement VOIR à quoi ressemblerait une génération y perdrait son
   * plan. L'activation reste le `PUT /programs/:id` existant, un geste séparé.
   */
  async writeGenerated(
    program: Prisma.ProgramUncheckedCreateInput,
    templates: Prisma.WorkoutTemplateUncheckedCreateInput[],
    exercises: Prisma.WorkoutTemplateExerciseCreateManyInput[],
    sets: Prisma.WorkoutTemplateSetCreateManyInput[],
    days: Prisma.ProgramDayCreateManyInput[],
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const { id, userId, ...rest } = program;
      await tx.program.upsert({
        where: { id },
        create: { id, userId, ...rest },
        update: { ...rest, deletedAt: null },
      });
      // Les jours d'abord : leur clé étrangère vers les modèles est
      // `SetNull`, donc effacer les modèles avant eux viderait les cases.
      await tx.programDay.deleteMany({ where: { programId: id } });
      await tx.workoutTemplateExercise.deleteMany({
        where: { template: { generatedFromProgramId: id } },
      });
      for (const template of templates) {
        const { id: templateId, userId: owner, ...templateRest } = template;
        await tx.workoutTemplate.upsert({
          where: { id: templateId },
          create: { id: templateId, userId: owner, ...templateRest },
          update: { ...templateRest, deletedAt: null },
        });
      }
      if (exercises.length > 0) await tx.workoutTemplateExercise.createMany({ data: exercises });
      if (sets.length > 0) await tx.workoutTemplateSet.createMany({ data: sets });
      if (days.length > 0) await tx.programDay.createMany({ data: days });
    });
  }

  /**
   * Le catalogue ENTIER, pour CALCULER les leviers.
   *
   * Il faut voir ce qui n'est pas dans le kit pour dire ce qu'un achat
   * débloquerait — et surtout ce qu'il ne débloquerait pas. Le filtre de
   * difficulté n'est volontairement PAS appliqué ici : c'est `levers.ts` qui
   * l'applique, parce qu'un matériel dont tous les exercices sont au-dessus
   * du niveau de la personne doit être nommé comme inutile, pas disparaître.
   */
  async fullCatalogue(): Promise<PoolExercise[]> {
    const rows = await this.prisma.exercise.findMany({
      where: { isPublished: true, muscles: { some: { role: ExerciseMuscleRole.PRIMARY } } },
      select: POOL_SELECT,
      orderBy: { slug: 'asc' },
    });
    return rows.map(toPoolExercise).filter((exercise) => exercise.primary !== '');
  }
}

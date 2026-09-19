import { type GenerationReport } from '@carlys/api-contracts';
import { type Prisma } from '@prisma/client';
import { derivedUuid } from '../../../common/utilities/derived-uuid';
import { GENERATION_UUID_NAMESPACE } from '../domain/generation/constants';
import { type PrescribedProgram } from '../domain/generation/types';

/**
 * La prescription traduite en LIGNES PRISMA — fonction pure, sans base.
 *
 * Extraite du service parce qu'elle n'a rien à y faire : elle ne décide rien,
 * elle transpose. Le service orchestre, ce fichier met en forme, le repository
 * écrit. Les trois se relisent séparément.
 */

export interface GeneratedRows {
  program: Prisma.ProgramUncheckedCreateInput;
  templates: Prisma.WorkoutTemplateUncheckedCreateInput[];
  exercises: Prisma.WorkoutTemplateExerciseCreateManyInput[];
  sets: Prisma.WorkoutTemplateSetCreateManyInput[];
  days: Prisma.ProgramDayCreateManyInput[];
}

/**
 * Identifiant DÉRIVÉ d'une ligne, comme ceux que le moteur produit déjà.
 *
 * C'est ce qui rend le rejeu inoffensif : réécrire le même programme réécrit
 * les mêmes lignes au lieu d'en créer un second jeu. L'idempotence se prouve
 * alors par égalité d'identifiants, sans journal.
 */
function rowId(programId: string, key: string): string {
  return derivedUuid(GENERATION_UUID_NAMESPACE, `${programId}:${key}`);
}

export function toRows(
  userId: string,
  programId: string,
  prescribed: PrescribedProgram,
  report: GenerationReport,
  name: string | undefined,
): GeneratedRows {
  const templates: Prisma.WorkoutTemplateUncheckedCreateInput[] = [];
  const exercises: Prisma.WorkoutTemplateExerciseCreateManyInput[] = [];
  const sets: Prisma.WorkoutTemplateSetCreateManyInput[] = [];

  for (const template of prescribed.templates) {
    templates.push({
      id: template.id,
      userId,
      name: template.name,
      notes: template.notes,
      // `estimatedDurationMinutes` reste NUL : le schéma dit « Saisie
      // facultative de l'utilisateur — JAMAIS calculée par le serveur ». La
      // durée estimée part en tête des notes, où elle n'usurpe rien.
      estimatedDurationMinutes: null,
      generatedFromProgramId: programId,
    });
    for (const exercise of template.exercises) {
      const exerciseRow = rowId(programId, `${template.id}:ex:${exercise.position}`);
      exercises.push({
        id: exerciseRow,
        templateId: template.id,
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseName,
        position: exercise.position,
        notes: exercise.notes,
      });
      for (const set of exercise.sets) {
        sets.push({
          id: rowId(programId, `${template.id}:ex:${exercise.position}:set:${set.position}`),
          templateExerciseId: exerciseRow,
          position: set.position,
          targetReps: set.targetReps,
          // `targetWeightKg` reste NUL : le serveur ne lit ni les records ni
          // l'historique dans cette tranche, donc il ne sait pas ce que la
          // personne soulève — le prescrire serait l'inventer.
          targetWeightKg: null,
          restSeconds: set.restSeconds,
        });
      }
    }
  }

  return {
    program: {
      id: programId,
      userId,
      name: name ?? prescribed.name,
      description: prescribed.description,
      weeksCount: prescribed.weeksCount,
      // INACTIF : activer désactiverait le programme en cours dans la même
      // transaction, donc une génération exploratoire ferait perdre son plan à
      // quelqu'un qui voulait seulement regarder.
      isActive: false,
      // Le rapport est un objet plat de types JSON : Prisma l'accepte tel
      // quel, sans conversion et donc sans perte.
      generationReport: report,
    },
    templates,
    exercises,
    sets,
    days: prescribed.days.map((day) => ({
      id: day.id,
      programId,
      weekNumber: day.weekNumber,
      dayOfWeek: day.dayOfWeek,
      templateId: day.templateId,
      label: day.label,
      isRest: day.isRest,
    })),
  };
}

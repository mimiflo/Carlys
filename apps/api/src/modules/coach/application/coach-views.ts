import {
  type BodyMetric,
  type PersonalRecord,
  type WorkoutSessionSummary,
  type WorkoutTemplateDetail,
  type WorkoutTemplateSet,
  type WorkoutTemplateSummary,
} from '@carlys/api-contracts';

/**
 * Ce que le coach LIT des séances, records et modèles — même logique que
 * `coach-meal-view.ts` pour les repas.
 *
 * Les contrats d'écran portent des identifiants de ligne, des révisions et
 * des champs vides qu'un écran utilise et qu'un modèle ne fait que relire.
 * Sur le serveur, le modèle tourne sur le processeur : chaque jeton relu à
 * chaque tour d'outil se paie en secondes de réponse, et un identifiant en
 * vaut une vingtaine. Restent ce qu'il cite et ce qu'il réutilise dans une
 * proposition (exerciseId, templateId, valeurs).
 */

/** « 2026-09-29T18:04Z » : la minute suffit, les secondes ne disent rien. */
const toMinute = (iso: string) => `${iso.slice(0, 16)}Z`;

/** « 2026-09-20 » : un record se date au jour. */
const toDay = (iso: string) => iso.slice(0, 10);

export function coachSessionView(session: WorkoutSessionSummary) {
  return {
    name: session.name,
    status: session.status,
    startedAt: toMinute(session.startedAt),
    durationMin: session.durationSeconds === null ? null : Math.round(session.durationSeconds / 60),
    setsCount: session.setsCount,
    totalVolumeKg: session.totalVolumeKg,
    templateName: session.templateName,
  };
}

export function coachRecordView(record: PersonalRecord) {
  return {
    exerciseId: record.exerciseId,
    exerciseName: record.exerciseName,
    recordType: record.recordType,
    value: record.value,
    reps: record.reps,
    weightKg: record.weightKg,
    achievedAt: toDay(record.achievedAt),
  };
}

/**
 * Une pesée : la valeur et le jour. L'identifiant, le type (toujours le
 * poids ici) et l'heure à la milliseconde triplaient la lecture : 10 pesées,
 * 783 jetons complètes contre 223 (mesuré le 1er octobre 2026).
 */
export function coachBodyMetricView(metric: BodyMetric) {
  return { value: metric.value, measuredAt: toDay(metric.measuredAt) };
}

/** Un modèle de la liste : de quoi choisir, et l'`id` pour le lire en détail. */
export function coachTemplateSummaryView(template: WorkoutTemplateSummary) {
  return {
    id: template.id,
    name: template.name,
    exercisesCount: template.exercisesCount,
    estimatedDurationMinutes: template.estimatedDurationMinutes,
    previewExerciseNames: template.previewExerciseNames,
    lastUsedAt: template.lastUsedAt === null ? null : toDay(template.lastUsedAt),
  };
}

export function coachTemplateView(template: WorkoutTemplateDetail) {
  return {
    id: template.id,
    name: template.name,
    estimatedDurationMinutes: template.estimatedDurationMinutes,
    ...(template.notes === null ? {} : { notes: template.notes }),
    exercises: template.exercises.map((exercise) => ({
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.exerciseName,
      ...(exercise.notes === null ? {} : { notes: exercise.notes }),
      sets: exercise.sets.map(coachSetView),
    })),
  };
}

/** Une série prévue sans son identifiant ni ses cibles vides. */
function coachSetView(set: WorkoutTemplateSet) {
  const { id: _id, position: _position, ...targets } = set;
  return Object.fromEntries(Object.entries(targets).filter(([, value]) => value !== null));
}

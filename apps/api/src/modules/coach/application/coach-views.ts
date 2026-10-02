import {
  type BodyMetric,
  type ExerciseSummary,
  type MealEntry,
  type PersonalRecord,
  type WorkoutSessionSummary,
  type WorkoutTemplateDetail,
  type WorkoutTemplateSet,
  type WorkoutTemplateSummary,
} from '@carlys/api-contracts';

/**
 * Ce que le coach LIT des séances, records, modèles et repas.
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
 * Un exercice du catalogue : de quoi le citer et le proposer (son `id`).
 * Le résumé d'écran portait le slug, l'image, les identifiants du groupe et
 * du matériel : 10 exercices, 1 962 jetons, contre 582 ici (mesuré le
 * 1er octobre 2026), relus à chaque tour d'outil.
 */
export function coachExerciseView(exercise: ExerciseSummary) {
  return {
    id: exercise.id,
    name: exercise.name,
    difficulty: exercise.difficulty,
    muscle: exercise.primaryMuscleGroup?.slug ?? null,
    equipment: exercise.equipment.map((item) => item.slug),
    // Seulement s'il surprend : un étirement ne fait pas une série de force.
    ...(exercise.type === 'STRENGTH' ? {} : { type: exercise.type }),
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

/**
 * Un repas du journal tel que le coach le lit. Le contrat de l'écran porte,
 * pour chaque aliment d'un repas composé, identifiant, code, groupe et quatre
 * valeurs : une semaine de repas à trente aliments pèserait des dizaines de
 * milliers de caractères pour dire « 120 g de poulet ». Le coach reçoit le
 * repas, son MOMENT (`null` : enregistré sans ; un dîner à 23 h n'est pas
 * une collation, et c'est une donnée enregistrée, pas une déduction de
 * l'heure), ses totaux (`computed` : calculés depuis ses aliments, pas
 * saisis), et ce qui le compose en clair, dans l'ordre du repas.
 */
export function coachMealView(meal: MealEntry) {
  return {
    name: meal.name,
    moment: meal.moment,
    eatenAt: meal.eatenAt,
    kcal: meal.kcal,
    proteinG: meal.proteinG,
    carbsG: meal.carbsG,
    fatG: meal.fatG,
    quantity: meal.quantity,
    quantityUnit: meal.quantityUnit,
    computed: meal.computed,
    foods: meal.components.map((component) => `${component.name} : ${component.quantityG} g`),
  };
}

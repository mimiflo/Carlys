import { type GenerationRelaxation } from '@carlys/api-contracts';
import { derivedUuid } from '../../../../common/utilities/derived-uuid';
import {
  GENERATION_UUID_NAMESPACE,
  GROUP_NEIGHBOURS,
  RECOVERY_HEAVY_SETS,
  RECOVERY_MIN_DAYS,
  SETS_PER_GROUP_PER_SESSION_MAX,
  TIMED_SECONDS_DEFAULT,
} from './constants';
import { GOAL_RULES } from './goal-rules';
import { prescriptionFor } from './progression';
import { planBudget } from './session-budget';
import {
  type PickContext,
  type PoolByGroup,
  isTimed,
  markUsed,
  needsLongRest,
  pickWithLadder,
} from './selection';
import { circularDistance, type Slot } from './splits';
import { type GenerationInput, type PrescribedExercise, type PrescribedTemplate } from './types';

/**
 * LA COMPOSITION D'UNE SÉANCE — le cœur du remplissage.
 *
 * Extrait du générateur, qui ORCHESTRE et ne doit pas aussi décider du contenu
 * d'un créneau. Le partage a été décidé avant d'écrire, pas quand le fichier a
 * débordé : ici vivent le budget appliqué, l'échelle de dégradation et les
 * deux contraintes qui se tiennent PAR CONSTRUCTION — le plafond de séries par
 * groupe et par séance, et l'espacement de récupération.
 */

export interface WorkingState {
  relaxations: GenerationRelaxation[];
  notes: string[];
  weeklySets: Map<string, number>;
}

export function relax(
  state: WorkingState,
  code: string,
  subject: string | null,
  expected: number | null,
  actual: number | null,
  message: string,
): void {
  state.relaxations.push({ code, subject, expected, actual, message });
}

/** Identifiants dérivés : rejouer la génération réécrit les MÊMES lignes. */
export function idFor(programId: string, key: string): string {
  return derivedUuid(GENERATION_UUID_NAMESPACE, `${programId}:${key}`);
}

/**
 * La graine de la rotation : toutes les entrées, et le kit TRIÉ.
 *
 * Le tri n'est pas cosmétique. `['banc','barre']` et `['barre','banc']`
 * décrivent le même kit ; sans tri, l'ordre d'arrivée des cases cochées
 * changerait le programme, ce qui ferait passer une donnée d'interface pour
 * une décision d'entraînement.
 */
export function seedOf(input: GenerationInput): string {
  const kit = [...input.equipmentSlugs].sort().join(',');
  return `${input.programId}|${input.goal}|${input.experience}|${input.weeklySessionsTarget}|${input.sessionMinutesTarget}|${kit}`;
}

/** Les groupes du découpage qu'aucun exercice jouable ne couvre en principal. */
export function uncoveredGroups(slots: Slot[], byGroup: PoolByGroup): string[] {
  const wanted = new Set(slots.flatMap((slot) => slot.groups));
  return [...wanted].filter((group) => (byGroup.get(group)?.length ?? 0) === 0).sort();
}

/** Ce que chaque jour de la semaine a déjà chargé, par groupe. */
export type WeekLoad = Map<number, Map<string, number>>;

/**
 * Ce groupe a-t-il déjà été chargé lourdement à moins de deux jours ?
 *
 * La distance est CIRCULAIRE : samedi et lundi sont à deux jours l'un de
 * l'autre, pas à cinq. C'est le détail que tout le monde oublie, et c'est
 * celui qui laisse passer le pire des enchaînements — la fin d'une semaine
 * collée au début de la suivante.
 */
function tropProche(weekLoad: WeekLoad, dayOfWeek: number, group: string): boolean {
  for (const [autreJour, charges] of weekLoad) {
    if (autreJour === dayOfWeek) continue;
    if ((charges.get(group) ?? 0) < RECOVERY_HEAVY_SETS) continue;
    if (circularDistance(autreJour, dayOfWeek) < RECOVERY_MIN_DAYS) return true;
  }
  return false;
}

/** Compose UNE séance : le budget décide du nombre, le découpage de l'ordre. */
export function buildTemplate(
  input: GenerationInput,
  slot: Slot,
  slotIndex: number,
  week: number,
  dayOfWeek: number,
  byGroup: PoolByGroup,
  bySecondary: PoolByGroup,
  usedInWeek: Map<string, number>,
  weekLoad: WeekLoad,
  state: WorkingState,
): PrescribedTemplate {
  const rules = GOAL_RULES[input.goal];
  const reference = prescriptionFor(rules, input.experience, week, true);
  const servable = slot.groups.filter((group) => (byGroup.get(group)?.length ?? 0) > 0);
  const poolSize = servable.reduce((total, group) => total + (byGroup.get(group)?.length ?? 0), 0);
  const plan = planBudget(
    input.goal,
    input.experience,
    input.sessionMinutesTarget,
    reference.sets,
    reference.reps,
    reference.restSeconds,
    poolSize,
  );

  const context: PickContext = {
    seed: seedOf(input),
    slotIndex,
    week,
    usedInSession: new Set(),
    usedInWeek,
    repeatRelaxed: false,
  };

  if (plan.overBudget) {
    relax(
      state,
      'R5_BUDGET_DEPASSE',
      slot.name,
      input.sessionMinutesTarget,
      null,
      `« ${slot.name} » déborde les ${input.sessionMinutesTarget} minutes visées : une séance de moins de deux mouvements n’en est pas une.`,
    );
  }

  const sessionLoad = new Map<string, number>();
  const exercises: PrescribedExercise[] = [];
  for (let index = 0; index < plan.exerciseCount && servable.length > 0; index += 1) {
    const group = servable[index % servable.length]!;
    let pick = pickWithLadder(byGroup, bySecondary, GROUP_NEIGHBOURS, group, context);
    if (pick === null) {
      // Le groupe est épuisé pour cette semaine : R2 autorise un troisième
      // passage plutôt que de laisser un trou dans la séance.
      context.repeatRelaxed = true;
      pick = pickWithLadder(byGroup, bySecondary, GROUP_NEIGHBOURS, group, context);
      if (pick !== null) {
        relax(
          state,
          'R2_REPETITION_HEBDOMADAIRE',
          group,
          2,
          3,
          `Peu d’exercices disponibles pour « ${group} » : un mouvement revient une troisième fois dans la semaine.`,
        );
      }
    }
    if (pick === null) continue;
    const chosen = pick.exercise;
    const dose = prescriptionFor(rules, input.experience, week, needsLongRest(chosen));

    // H7 — le plafond par groupe et par SÉANCE. Sans lui, un découpage à trois
    // groupes et dix exercices empile vingt séries sur les pectoraux : le
    // volume hebdomadaire serait juste, la séance serait absurde.
    const dejaDansLaSeance = sessionLoad.get(chosen.primary) ?? 0;
    if (dejaDansLaSeance + dose.sets > SETS_PER_GROUP_PER_SESSION_MAX) continue;

    // H2 — la RÉCUPÉRATION, tenue par construction et non par chance
    // d'écriture. Charger lourdement un groupe à moins de deux jours du
    // dernier passage ne le développe pas, il l'empêche de récupérer. On
    // saute le créneau plutôt que de l'écrire, et la contrainte tient même si
    // quelqu'un retouche la table de placement demain.
    if (dose.sets >= RECOVERY_HEAVY_SETS && tropProche(weekLoad, dayOfWeek, chosen.primary)) {
      continue;
    }

    if (pick.step === 'secondaire') {
      relax(
        state,
        'R3_ROLE_SECONDAIRE',
        group,
        null,
        null,
        `« ${group} » est servi par un exercice où il travaille en second : il est sollicité, pas entraîné.`,
      );
    }
    if (pick.step === 'voisin') {
      relax(
        state,
        'R4_GROUPE_VOISIN',
        group,
        null,
        null,
        `Aucun exercice disponible pour « ${group} » cette séance : le créneau part sur « ${pick.servedGroup} ».`,
      );
    }
    markUsed(chosen, context);
    sessionLoad.set(chosen.primary, dejaDansLaSeance + dose.sets);

    const rest = plan.format.restOverrideSeconds ?? dose.restSeconds;
    const timed = isTimed(chosen);
    exercises.push({
      exerciseId: chosen.id,
      exerciseName: chosen.name,
      position: exercises.length,
      notes: timed
        ? `${dose.sets} × ${TIMED_SECONDS_DEFAULT} s`
        : 'Monte la charge quand tu tiens le haut de la fourchette.',
      sets: Array.from({ length: dose.sets }, (_unused, position) => ({
        position,
        // Une durée n'est PAS un nombre de répétitions : écrire 45 ici ferait
        // entrer « 45 répétitions de planche » dans les records personnels et
        // les y laisserait pour toujours.
        targetReps: timed ? null : dose.reps,
        restSeconds: rest,
      })),
    });
    const previous = state.weeklySets.get(chosen.primary) ?? 0;
    state.weeklySets.set(chosen.primary, previous + dose.sets);
  }

  const jour = weekLoad.get(dayOfWeek) ?? new Map<string, number>();
  for (const [group, sets] of sessionLoad) jour.set(group, (jour.get(group) ?? 0) + sets);
  weekLoad.set(dayOfWeek, jour);

  const setsCount = exercises.reduce((total, exercise) => total + exercise.sets.length, 0);
  const minutes = Math.round(
    (plan.warmupSeconds +
      exercises.reduce(
        (total, exercise) =>
          total +
          plan.format.transitionSeconds +
          exercise.sets.length * (TIMED_SECONDS_DEFAULT + (exercise.sets[0]?.restSeconds ?? 0)) -
          (exercise.sets[0]?.restSeconds ?? 0),
        0,
      )) /
      60,
  );

  return {
    id: idFor(input.programId, `template:${slotIndex}:${week}`),
    name: `${slot.name} — semaine ${week}`,
    // La durée va dans les NOTES, pas dans `estimatedDurationMinutes` : le
    // schéma dit « Saisie facultative de l'utilisateur — JAMAIS calculée par
    // le serveur », et une règle écrite au schéma ne se contourne pas.
    notes: `≈ ${minutes} min · ${exercises.length} exercices · ${setsCount} séries · généré`,
    exercises,
  };
}

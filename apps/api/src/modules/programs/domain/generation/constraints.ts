import { type TrainingExperience } from '@prisma/client';
import {
  EXERCISES_PER_SESSION_MAX,
  EXERCISE_WEEKLY_REPEAT_RELAXED,
  PULL_GROUPS,
  PUSH_GROUPS,
  RECOVERY_HEAVY_SETS,
  RECOVERY_MIN_DAYS,
  SETS_PER_GROUP_PER_SESSION_MAX,
} from './constants';
import { type GoalRules } from './goal-rules';
import { circularDistance } from './splits';
import { type PoolExercise, type PrescribedDay, type PrescribedTemplate } from './types';

/**
 * LES CONTRAINTES DURES, et la fonction qui les relit.
 *
 * `verify()` est appelée DEUX FOIS : par le générateur à la fin de son
 * travail, et par le test sur l'ensemble des combinaisons d'entrées. C'est
 * tout l'intérêt — l'invariant n'est pas récrit à la main dans le test, où il
 * finirait par diverger du code qu'il surveille ; le moteur se relit avec
 * l'outil du test.
 *
 * H1 FRÉQUENCE   : exactement `sessions` jours d'entraînement par semaine.
 * H2 RÉCUPÉRATION: deux séances chargeant lourdement le même groupe sont
 *                  séparées d'au moins deux jours, en distance CIRCULAIRE.
 * H3 TEMPS       : vérifié à la composition (`session-budget.ts`).
 * H4 MATÉRIEL    : `equipment ⊆ kit`. NON RELÂCHABLE.
 * H5 DIFFICULTÉ  : jamais au-dessus du plafond de l'expérience. NON RELÂCHABLE.
 * H6 DROITS      : un exercice premium exige l'entitlement. NON RELÂCHABLE.
 * H7 VOLUME      : séries hebdomadaires par groupe dans la fourchette.
 * H8 UNICITÉ     : un exercice une fois par séance, trois fois par semaine au plus.
 *
 * H4, H5 et H6 sont tenues par le REPOSITORY : rien d'interdit n'entre dans
 * le pool. `verify` les recontrôle quand même sur le pool reçu, parce qu'une
 * contrainte dont le relâchement serait un DANGER et non une déception mérite
 * de tomber deux fois plutôt que zéro.
 */

export interface Violation {
  rule: string;
  subject: string;
  detail: string;
}

export interface VerifyInput {
  days: PrescribedDay[];
  templates: PrescribedTemplate[];
  pool: PoolExercise[];
  rules: GoalRules;
  experience: TrainingExperience;
  sessionsPerWeek: number;
  weeksCount: number;
}

/** Séries par groupe principal d'un modèle donné. */
function setsByGroup(
  template: PrescribedTemplate,
  byId: Map<string, PoolExercise>,
): Map<string, number> {
  const counts = new Map<string, number>();
  for (const exercise of template.exercises) {
    const known = byId.get(exercise.exerciseId);
    if (known === undefined) continue;
    counts.set(known.primary, (counts.get(known.primary) ?? 0) + exercise.sets.length);
  }
  return counts;
}

function checkFrequency(input: VerifyInput, violations: Violation[]): void {
  for (let week = 1; week <= input.weeksCount; week += 1) {
    const active = input.days.filter((day) => day.weekNumber === week && !day.isRest);
    if (active.length !== input.sessionsPerWeek) {
      violations.push({
        rule: 'H1_FREQUENCE',
        subject: `semaine ${week}`,
        detail: `${active.length} séances au lieu de ${input.sessionsPerWeek}`,
      });
    }
    const slots = new Set(active.map((day) => day.dayOfWeek));
    if (slots.size !== active.length) {
      violations.push({
        rule: 'H1_FREQUENCE',
        subject: `semaine ${week}`,
        detail: 'deux séances le même jour',
      });
    }
  }
}

function checkRecovery(
  input: VerifyInput,
  byTemplate: Map<string, PrescribedTemplate>,
  byId: Map<string, PoolExercise>,
  violations: Violation[],
): void {
  for (let week = 1; week <= input.weeksCount; week += 1) {
    const charged: { day: number; group: string }[] = [];
    for (const day of input.days) {
      if (day.weekNumber !== week || day.templateId === null) continue;
      const template = byTemplate.get(day.templateId);
      if (template === undefined) continue;
      for (const [group, sets] of setsByGroup(template, byId)) {
        if (sets >= RECOVERY_HEAVY_SETS) charged.push({ day: day.dayOfWeek, group });
      }
    }
    for (let a = 0; a < charged.length; a += 1) {
      for (let b = a + 1; b < charged.length; b += 1) {
        const left = charged[a]!;
        const right = charged[b]!;
        if (left.group !== right.group) continue;
        if (circularDistance(left.day, right.day) < RECOVERY_MIN_DAYS) {
          violations.push({
            rule: 'H2_RECUPERATION',
            subject: left.group,
            detail: `jours ${left.day} et ${right.day} en semaine ${week}`,
          });
        }
      }
    }
  }
}

function checkSessionShape(
  input: VerifyInput,
  byId: Map<string, PoolExercise>,
  violations: Violation[],
): void {
  const ceiling = EXERCISES_PER_SESSION_MAX[input.experience];
  for (const template of input.templates) {
    if (template.exercises.length > ceiling) {
      violations.push({
        rule: 'H3_TEMPS',
        subject: template.name,
        detail: `${template.exercises.length} exercices au-dessus du plafond ${ceiling}`,
      });
    }
    const seen = new Set<string>();
    for (const exercise of template.exercises) {
      if (seen.has(exercise.exerciseId)) {
        violations.push({
          rule: 'H8_UNICITE',
          subject: template.name,
          detail: `${exercise.exerciseName} deux fois dans la même séance`,
        });
      }
      seen.add(exercise.exerciseId);
      if (!byId.has(exercise.exerciseId)) {
        violations.push({
          rule: 'H4_MATERIEL',
          subject: template.name,
          detail: `${exercise.exerciseName} hors du pool jouable`,
        });
      }
    }
    for (const [group, sets] of setsByGroup(template, byId)) {
      if (sets > SETS_PER_GROUP_PER_SESSION_MAX) {
        violations.push({
          rule: 'H7_VOLUME',
          subject: group,
          detail: `${sets} séries en une séance, plafond ${SETS_PER_GROUP_PER_SESSION_MAX}`,
        });
      }
    }
  }
}

function checkWeeklyRepeats(
  input: VerifyInput,
  byTemplate: Map<string, PrescribedTemplate>,
  violations: Violation[],
): void {
  for (let week = 1; week <= input.weeksCount; week += 1) {
    const counts = new Map<string, number>();
    for (const day of input.days) {
      if (day.weekNumber !== week || day.templateId === null) continue;
      const template = byTemplate.get(day.templateId);
      if (template === undefined) continue;
      for (const exercise of template.exercises) {
        counts.set(exercise.exerciseId, (counts.get(exercise.exerciseId) ?? 0) + 1);
      }
    }
    for (const [id, count] of counts) {
      if (count > EXERCISE_WEEKLY_REPEAT_RELAXED) {
        violations.push({
          rule: 'H8_UNICITE',
          subject: id,
          detail: `${count} passages en semaine ${week}, plafond ${EXERCISE_WEEKLY_REPEAT_RELAXED}`,
        });
      }
    }
  }
}

/**
 * H10 — les positions sont CONTIGUËS, à partir de zéro.
 *
 * L'unicité `(templateId, position)` est en base, la contiguïté ne l'est pas :
 * un trou passerait l'écriture et ferait sauter une ligne dans l'écran de
 * séance. Le validateur des propositions du coach fait exactement ce contrôle,
 * pour la même raison.
 */
function checkContiguity(input: VerifyInput, violations: Violation[]): void {
  for (const template of input.templates) {
    const positions = template.exercises.map((exercise) => exercise.position).sort((a, b) => a - b);
    const contigus = positions.every((position, index) => position === index);
    if (!contigus) {
      violations.push({
        rule: 'H10_CONTIGUITE',
        subject: template.name,
        detail: `positions ${positions.join(', ')} au lieu de 0..${positions.length - 1}`,
      });
    }
    for (const exercise of template.exercises) {
      const setPositions = exercise.sets.map((set) => set.position).sort((a, b) => a - b);
      if (!setPositions.every((position, index) => position === index)) {
        violations.push({
          rule: 'H10_CONTIGUITE',
          subject: exercise.exerciseName,
          detail: `séries ${setPositions.join(', ')} au lieu de 0..${setPositions.length - 1}`,
        });
      }
    }
  }
}

/** Le calendrier est COMPLET : `weeksCount × 7` cases, sans trou ni doublon. */
function checkCalendar(input: VerifyInput, violations: Violation[]): void {
  const expected = input.weeksCount * 7;
  if (input.days.length !== expected) {
    violations.push({
      rule: 'H1_FREQUENCE',
      subject: 'calendrier',
      detail: `${input.days.length} jours au lieu de ${expected}`,
    });
  }
  const slots = new Set(input.days.map((day) => `${day.weekNumber}-${day.dayOfWeek}`));
  if (slots.size !== input.days.length) {
    violations.push({ rule: 'H1_FREQUENCE', subject: 'calendrier', detail: 'case en double' });
  }
}

/** Zéro violation, ou la liste de ce qui cloche — nommé, jamais un booléen. */
export function verify(input: VerifyInput): Violation[] {
  const violations: Violation[] = [];
  const byId = new Map(input.pool.map((exercise) => [exercise.id, exercise]));
  const byTemplate = new Map(input.templates.map((template) => [template.id, template]));

  checkCalendar(input, violations);
  checkFrequency(input, violations);
  checkRecovery(input, byTemplate, byId, violations);
  checkSessionShape(input, byId, violations);
  checkWeeklyRepeats(input, byTemplate, violations);
  checkContiguity(input, violations);
  return violations;
}

/**
 * H9 — le RATIO TIRAGE / POUSSÉE, rendu séparément.
 *
 * Il n'entre pas dans `verify()` parce que ce n'est pas une contrainte DURE :
 * sur un catalogue où le tirage sans matériel tient à un exercice, l'exiger
 * rendrait tout programme infaisable. C'est une information que le rapport
 * porte, et c'est la seule qui protège l'épaule sur huit semaines.
 */
export function pullToPushRatio(volumes: Map<string, number>): number | null {
  const sum = (groups: string[]): number =>
    groups.reduce((total, group) => total + (volumes.get(group) ?? 0), 0);
  const push = sum(PUSH_GROUPS);
  const pull = sum(PULL_GROUPS);
  if (push === 0) return null;
  return pull / push;
}

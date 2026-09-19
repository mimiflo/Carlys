import { TrainingExperience, TrainingGoal } from '@prisma/client';
import { DAY_PLACEMENT, SESSIONS_PER_WEEK_MAX } from './constants';
import { GOAL_RULES } from './goal-rules';

/**
 * LE DÉCOUPAGE : quels groupes travaillent quel jour.
 *
 * Un créneau (`Slot`) est une SÉANCE TYPE, pas une séance : le même créneau
 * revient chaque semaine avec des dosages qui montent et, souvent, d'autres
 * exercices. Les jours d'endurance n'ont pas de créneau — ils portent un
 * intitulé libre, parce que le catalogue ne contient aucun exercice de
 * course, de rameur ni de traîneau.
 */

export interface Slot {
  /** « Haut du corps A », « Poussée », « Jambes »… — le nom du jour. */
  name: string;
  /** Groupes servis, dans l'ordre de priorité de remplissage. */
  groups: string[];
}

const FULL = ['pectoraux', 'dos', 'quadriceps', 'ischio-jambiers', 'epaules', 'abdominaux'];
const FULL_B = ['dos', 'quadriceps', 'pectoraux', 'fessiers', 'triceps', 'abdominaux'];
const FULL_C = ['epaules', 'ischio-jambiers', 'dos', 'biceps', 'mollets', 'lombaires'];
const PUSH = ['pectoraux', 'epaules', 'triceps'];
const PULL = ['dos', 'biceps', 'lombaires'];
const LEGS = ['quadriceps', 'ischio-jambiers', 'fessiers', 'mollets'];
const UPPER_A = ['pectoraux', 'dos', 'epaules', 'triceps', 'biceps'];
const UPPER_B = ['dos', 'pectoraux', 'biceps', 'epaules', 'triceps'];
const LOWER_A = ['quadriceps', 'ischio-jambiers', 'fessiers', 'abdominaux'];
const LOWER_B = ['ischio-jambiers', 'quadriceps', 'mollets', 'lombaires', 'abdominaux'];

/**
 * `avant-bras` n'est le groupe principal d'AUCUN créneau, et ce n'est pas un
 * oubli : aucun exercice du catalogue ne le porte en principal, matériel
 * compris. Lui ouvrir un créneau produirait un jour vide. Il reste servi en
 * secondaire par les tirages et les curls.
 */

function strengthSplit(sessions: number, experience: TrainingExperience): Slot[] {
  const debutant = experience === TrainingExperience.BEGINNER;
  switch (sessions) {
    case 1:
      return [{ name: 'Corps entier', groups: FULL }];
    case 2:
      return [
        { name: 'Corps entier A', groups: FULL },
        { name: 'Corps entier B', groups: FULL_B },
      ];
    case 3:
      // Le débutant gagne à revoir chaque mouvement trois fois par semaine ;
      // au-delà, la division pousser/tirer/jambes concentre mieux l'effort.
      return debutant
        ? [
            { name: 'Corps entier A', groups: FULL },
            { name: 'Corps entier B', groups: FULL_B },
            { name: 'Corps entier C', groups: FULL_C },
          ]
        : [
            { name: 'Poussée', groups: PUSH },
            { name: 'Tirage', groups: PULL },
            { name: 'Jambes', groups: LEGS },
          ];
    case 4:
      return [
        { name: 'Haut du corps A', groups: UPPER_A },
        { name: 'Bas du corps A', groups: LOWER_A },
        { name: 'Haut du corps B', groups: UPPER_B },
        { name: 'Bas du corps B', groups: LOWER_B },
      ];
    case 5:
      return [
        { name: 'Poussée', groups: PUSH },
        { name: 'Tirage', groups: PULL },
        { name: 'Jambes', groups: LEGS },
        { name: 'Haut du corps', groups: UPPER_B },
        { name: 'Bas du corps', groups: LOWER_B },
      ];
    case 6:
      return [
        { name: 'Poussée A', groups: PUSH },
        { name: 'Tirage A', groups: PULL },
        { name: 'Jambes A', groups: LEGS },
        { name: 'Poussée B', groups: PUSH },
        { name: 'Tirage B', groups: PULL },
        { name: 'Jambes B', groups: LEGS },
      ];
    default:
      return [
        { name: 'Poussée A', groups: PUSH },
        { name: 'Tirage A', groups: PULL },
        { name: 'Jambes A', groups: LEGS },
        { name: 'Poussée B', groups: PUSH },
        { name: 'Tirage B', groups: PULL },
        { name: 'Jambes B', groups: LEGS },
        { name: 'Rappel points faibles', groups: FULL_C },
      ];
  }
}

/** Renforcement du coureur ou du concurrent Hyrox : jambes et tronc d'abord. */
const ENDURANCE_STRENGTH: Slot[] = [
  { name: 'Renforcement jambes et tronc', groups: [...LOWER_A, 'lombaires'] },
  { name: 'Renforcement complémentaire', groups: [...LOWER_B, 'dos'] },
];

/**
 * Le rythme demandé est un SOUHAIT, pas une contrainte dure.
 *
 * On le ramène dans la fourchette de l'objectif et sous le plafond de
 * l'expérience, et on le DIT au rapport : « Tu visais 7 séances ; l'objectif
 * Force et ton niveau en retiennent 5. » Se taire ferait passer la règle pour
 * une panne.
 */
export function normalizeSessions(
  goal: TrainingGoal,
  experience: TrainingExperience,
  wanted: number,
): number {
  const rules = GOAL_RULES[goal];
  const max = Math.min(rules.sessionsMax, SESSIONS_PER_WEEK_MAX[experience]);
  return Math.min(Math.max(wanted, rules.sessionsMin), max);
}

/** Combien de jours partent en endurance à intitulé libre. */
export function enduranceDayCount(goal: TrainingGoal, sessions: number): number {
  const rules = GOAL_RULES[goal];
  const wanted = Math.round(sessions * rules.cardioShare);
  // `sessions - 1` garantit qu'il reste toujours une séance dans
  // l'application : un programme sans aucun modèle n'est pas un programme.
  return Math.min(Math.max(wanted, rules.cardioFloor), Math.max(sessions - 1, 0));
}

/**
 * Les créneaux de renforcement d'une semaine, endurance déduite.
 *
 * MARATHON et HYROX ont leurs propres créneaux : leur renforcement n'est pas
 * un programme de musculation amputé, il sert la course ou les ateliers.
 */
export function buildSlots(
  goal: TrainingGoal,
  experience: TrainingExperience,
  sessions: number,
): Slot[] {
  const strengthDays = sessions - enduranceDayCount(goal, sessions);
  if (goal === TrainingGoal.MARATHON || goal === TrainingGoal.HYROX) {
    return ENDURANCE_STRENGTH.slice(0, Math.max(strengthDays, 1));
  }
  return strengthSplit(strengthDays, experience);
}

/**
 * Les jours de la semaine retenus, triés.
 *
 * Les jours d'endurance viennent APRÈS les jours de renforcement dans la
 * liste des créneaux, mais ils se placent en alternance dans la semaine : le
 * tri final sur `dayOfWeek` s'en charge, et la contrainte de récupération
 * (H2) vérifie que l'alternance obtenue tient.
 */
export function placementFor(sessions: number): number[] {
  return DAY_PLACEMENT[sessions] ?? DAY_PLACEMENT[7]!;
}

/** Distance CIRCULAIRE entre deux jours : samedi et lundi sont à 2 jours. */
export function circularDistance(a: number, b: number): number {
  const raw = Math.abs(a - b);
  return Math.min(raw, 7 - raw);
}

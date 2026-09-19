import { type GenerationInput, type PrescribedDay, type PrescribedTemplate } from './types';
import { enduranceLabel } from './endurance-catalog';
import { GOAL_RULES } from './goal-rules';
import { dayLabel } from './progression';
import { idFor } from './slot-filler';
import { placementFor, type Slot } from './splits';

/**
 * LE CALENDRIER — quel jour porte quoi, sur toutes les semaines.
 *
 * Séparé de la composition des séances : l'un décide du CONTENU, l'autre de
 * la PLACE. Les mêler dans un seul fichier rendait illisible le point qui
 * compte — le plan de la semaine est calculé UNE fois et partagé entre les
 * deux, sans quoi la contrainte de récupération vérifierait une semaine
 * différente de celle qu'on écrit.
 */

/**
 * LE PLAN D'UNE SEMAINE : quel jour porte quoi.
 *
 * Calculé UNE fois et partagé entre la composition des séances et l'écriture
 * du calendrier. Deux calculs séparés finiraient par diverger — et la
 * contrainte de récupération, qui a besoin de savoir quel jour porte quel
 * créneau, serait vérifiée sur une autre semaine que celle qu'on écrit.
 */
export interface DaySlot {
  dayOfWeek: number;
  /** Rang du créneau de renforcement, ou `null` pour un jour d'endurance. */
  slotIndex: number | null;
  /** Rang du jour d'endurance dans la semaine, pour choisir son intitulé. */
  enduranceRank: number;
}

export function weekPlan(sessions: number, enduranceDays: number, slotCount: number): DaySlot[] {
  const placement = placementFor(sessions);
  return placement.map((dayOfWeek, position) => {
    const rank =
      position % 2 === 1 ? enduranceIndex(position, placement.length, enduranceDays) : -1;
    return {
      dayOfWeek,
      slotIndex:
        rank >= 0 ? null : strengthIndex(position, placement.length, enduranceDays, slotCount),
      enduranceRank: rank,
    };
  });
}

/** Le calendrier complet : `weeksCount × 7` cases, repos compris. */
export function buildDays(
  input: GenerationInput,
  slots: Slot[],
  plan: DaySlot[],
  templatesByWeek: Map<string, PrescribedTemplate>,
  weeksCount: number,
): PrescribedDay[] {
  const days: PrescribedDay[] = [];

  for (let week = 1; week <= weeksCount; week += 1) {
    const active = new Map<number, PrescribedDay>();
    for (const entry of plan) {
      const id = idFor(input.programId, `day:${week}:${entry.dayOfWeek}`);
      if (entry.slotIndex === null) {
        active.set(entry.dayOfWeek, {
          id,
          weekNumber: week,
          dayOfWeek: entry.dayOfWeek,
          templateId: null,
          label: enduranceLabel(input.goal, week, entry.enduranceRank),
          isRest: false,
        });
        continue;
      }
      const template = templatesByWeek.get(`${entry.slotIndex}:${week}`);
      const slot = slots[entry.slotIndex];
      active.set(entry.dayOfWeek, {
        id,
        weekNumber: week,
        dayOfWeek: entry.dayOfWeek,
        templateId: template?.id ?? null,
        label: dayLabel(
          slot?.name ?? 'Séance',
          template !== undefined && isDeloadWeek(input, week),
        ),
        isRest: false,
      });
    }

    for (let dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek += 1) {
      const planned = active.get(dayOfWeek);
      days.push(
        planned ?? {
          id: idFor(input.programId, `day:${week}:${dayOfWeek}`),
          weekNumber: week,
          dayOfWeek,
          templateId: null,
          label: 'Repos',
          isRest: true,
        },
      );
    }
  }
  return days;
}

function isDeloadWeek(input: GenerationInput, week: number): boolean {
  return GOAL_RULES[input.goal].mesocycle[(week - 1) % 4]!.deload;
}

/** Position du jour d'endurance, ou -1 si ce jour est un renforcement. */
function enduranceIndex(position: number, total: number, enduranceDays: number): number {
  const odds: number[] = [];
  for (let index = 1; index < total; index += 2) odds.push(index);
  const rank = odds.indexOf(position);
  return rank >= 0 && rank < enduranceDays ? rank : -1;
}

/** Rang du créneau de renforcement porté par ce jour. */
function strengthIndex(
  position: number,
  total: number,
  enduranceDays: number,
  slotCount: number,
): number {
  let rank = 0;
  for (let index = 0; index < position; index += 1) {
    if (enduranceIndex(index, total, enduranceDays) < 0) rank += 1;
  }
  return slotCount === 0 ? 0 : rank % slotCount;
}

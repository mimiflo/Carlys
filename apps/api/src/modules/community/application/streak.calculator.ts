/**
 * Série de constance : nombre de JOURS CALENDAIRES consécutifs avec au moins
 * une séance terminée, en remontant depuis aujourd'hui — ou depuis hier, car
 * une série n'est pas brisée tant que la journée en cours n'est pas finie.
 *
 * Les jours sont découpés dans le FUSEAU DE L'UTILISATEUR (UserProfile.
 * timezone) : une séance à 23 h 30 à Paris compte pour le jour parisien,
 * pas pour le lendemain UTC.
 */
import { addDays, dayKeyInZone } from '../../../common/utilities/civil-day';

/**
 * `dayKeyInZone` vit dans `common/utilities/civil-day.ts` : le calendrier
 * de programme en a besoin pour la même raison que la série de constance,
 * et une seconde copie divergerait au premier correctif.
 */

const previousDayKey = (dayKey: string): string => addDays(dayKey, -1);

export function computeStreakDays(input: {
  /** Débuts des séances TERMINÉES, ordre indifférent. */
  sessionStarts: Date[];
  timeZone: string;
  now: Date;
}): number {
  const trained = new Set(input.sessionStarts.map((start) => dayKeyInZone(start, input.timeZone)));
  if (trained.size === 0) {
    return 0;
  }

  const today = dayKeyInZone(input.now, input.timeZone);
  // La série peut finir aujourd'hui, ou hier si rien n'est encore fait.
  let cursor = trained.has(today) ? today : previousDayKey(today);
  let streak = 0;
  while (trained.has(cursor)) {
    streak += 1;
    cursor = previousDayKey(cursor);
  }
  return streak;
}

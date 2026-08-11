/**
 * Série de constance : nombre de JOURS CALENDAIRES consécutifs avec au moins
 * une séance terminée, en remontant depuis aujourd'hui — ou depuis hier, car
 * une série n'est pas brisée tant que la journée en cours n'est pas finie.
 *
 * Les jours sont découpés dans le FUSEAU DE L'UTILISATEUR (UserProfile.
 * timezone) : une séance à 23 h 30 à Paris compte pour le jour parisien,
 * pas pour le lendemain UTC.
 */

/** `YYYY-MM-DD` de `date` dans `timeZone` (repli UTC si fuseau inconnu). */
export function dayKeyInZone(date: Date, timeZone: string): string {
  try {
    // en-CA donne nativement YYYY-MM-DD.
    return new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(date);
  } catch {
    return date.toISOString().slice(0, 10);
  }
}

function previousDayKey(dayKey: string): string {
  // Midi UTC : reculer de 24 h ne peut pas sauter un jour, quel que soit le
  // calendrier — les clés sont déjà des jours abstraits, sans fuseau.
  const noon = new Date(`${dayKey}T12:00:00Z`);
  noon.setUTCDate(noon.getUTCDate() - 1);
  return noon.toISOString().slice(0, 10);
}

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

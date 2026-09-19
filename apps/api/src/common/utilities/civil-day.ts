/**
 * Les JOURS CIVILS, écrits `YYYY-MM-DD`, et l'arithmétique qui va avec.
 *
 * POURQUOI UNE CHAÎNE ET PAS UN `Date`. Un jour civil n'est pas un instant :
 * « le 21 septembre » ne devient pas « le 20 » parce qu'on le regarde depuis
 * Montréal. Servi en `Date`, il traverse le contrat en ISO 8601 complet, et
 * le mobile lui applique le `.toLocal()` qu'il applique partout ailleurs —
 * à raison, puisque tout le reste EST un instant. Une chaîne, elle, ne se
 * convertit pas par accident.
 *
 * Ce module a été extrait de `community/application/streak.calculator.ts`,
 * qui portait `dayKeyInZone` en un seul exemplaire : le calendrier de
 * programme en a besoin pour savoir ce que « déjà passé » veut dire, et en
 * écrire une seconde version serait la dupliquer ; l'importer depuis
 * `community` collerait deux modules métier qui n'ont rien à se dire.
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

/**
 * Midi UTC du jour civil `dayKey`.
 *
 * Midi, et non minuit : c'est ce qui rend l'arithmétique de jours insensible
 * aux décalages d'une heure. Minuit UTC ± une heure change de JOUR ; midi
 * ± une heure reste le même jour, quel que soit le fuseau ou le passage à
 * l'heure d'été.
 */
function noonOf(dayKey: string): Date {
  return new Date(`${dayKey}T12:00:00Z`);
}

/** Le jour civil `days` jours après `dayKey` (négatif pour reculer). */
export function addDays(dayKey: string, days: number): string {
  const noon = noonOf(dayKey);
  noon.setUTCDate(noon.getUTCDate() + days);
  return noon.toISOString().slice(0, 10);
}

/** Nombre de jours de `from` à `to` — négatif si `to` précède `from`. */
export function daysBetween(from: string, to: string): number {
  const millis = noonOf(to).getTime() - noonOf(from).getTime();
  return Math.round(millis / 86_400_000);
}

/** 1 (lundi) à 7 (dimanche) — la numérotation de `ProgramDay.dayOfWeek`. */
export function isoWeekday(dayKey: string): number {
  // `getUTCDay()` rend 0 pour dimanche : le décalage le remet en 7e position,
  // qui est celle du dimanche dans la grille du programme.
  return noonOf(dayKey).getUTCDay() || 7;
}

/** Le lundi de la semaine de `dayKey` — lui-même si c'est déjà un lundi. */
export function mondayOf(dayKey: string): string {
  return addDays(dayKey, 1 - isoWeekday(dayKey));
}

/** Vrai si la chaîne a la forme `YYYY-MM-DD` ET désigne un jour réel. */
export function isDayKey(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  // Le motif laisse passer le 31 février : seul l'aller-retour le refuse,
  // parce que `Date` normalise silencieusement vers le 3 mars.
  const noon = noonOf(value);
  return !Number.isNaN(noon.getTime()) && noon.toISOString().slice(0, 10) === value;
}

/**
 * Le jour civil d'une colonne `@db.Date`.
 *
 * Prisma rend un `Date` positionné à minuit UTC pour ce type : lire ses
 * composantes UTC redonne exactement le jour écrit, alors que passer par
 * l'heure locale du serveur le ferait reculer d'un jour à l'ouest de
 * Greenwich.
 */
export function dayKeyOfColumn(value: Date): string {
  return value.toISOString().slice(0, 10);
}

/**
 * La valeur à ÉCRIRE dans une colonne `@db.Date` pour le jour `dayKey`.
 *
 * Minuit UTC : PostgreSQL ne garde que la partie date, et c'est celle-là
 * qu'on veut voir revenir intacte.
 */
export function columnOfDayKey(dayKey: string): Date {
  return new Date(`${dayKey}T00:00:00Z`);
}

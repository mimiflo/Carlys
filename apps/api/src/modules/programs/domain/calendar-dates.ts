import { addDays, daysBetween, isoWeekday, mondayOf } from '../../../common/utilities/civil-day';
import { type ProgramDayStatus } from '@carlys/api-contracts';

/**
 * LA DATE D'UNE CASE DU PROGRAMME — calcul pur, sans base ni horloge.
 *
 * Un programme est une GRILLE : semaine 1 à N, jour 1 (lundi) à 7
 * (dimanche). `Program.startsOn` lui donne une origine, et tout le reste en
 * découle par arithmétique de jours civils.
 *
 * L'ANCRE EST LE LUNDI de la semaine de `startsOn`, pas `startsOn` lui-même.
 * C'est la seule règle qui garde son sens à `dayOfWeek` : le générateur
 * espace les séances par jour de la SEMAINE (lundi, mercredi, vendredi), et
 * l'écran les nomme ainsi. Faire du jour de départ le « jour 1 » quel qu'il
 * soit renommerait tout le vocabulaire — un « lundi » qui tombe un jeudi.
 *
 * Reste le cas de celui qui commence un mercredi : lundi et mardi de sa
 * semaine 1 sont AVANT son départ. Ils ne sont ni faits ni manqués, ils sont
 * HORS PÉRIODE. Sans cette troisième nuance, le calendrier accueillerait sa
 * première ouverture par deux cases rouges, pour des séances que personne
 * n'avait promis de faire.
 */

/** Le lundi qui ancre la grille d'un programme commencé le `startsOn`. */
export function anchorOf(startsOn: string): string {
  return mondayOf(startsOn);
}

/** Le jour civil de la case (`weekNumber`, `dayOfWeek`) d'un programme ancré. */
export function dateOfSlot(anchor: string, weekNumber: number, dayOfWeek: number): string {
  return addDays(anchor, 7 * (weekNumber - 1) + (dayOfWeek - 1));
}

/**
 * La semaine du programme qui contient `dayKey` — `null` hors du plan.
 *
 * Sert à ouvrir le calendrier sur la semaine en cours plutôt que sur la
 * première : trois semaines après le départ, personne ne veut relire la
 * semaine 1.
 */
export function weekOfDate(anchor: string, weeksCount: number, dayKey: string): number | null {
  const ecart = daysBetween(anchor, dayKey);
  if (ecart < 0) return null;
  const semaine = Math.floor(ecart / 7) + 1;
  return semaine > weeksCount ? null : semaine;
}

/** Le dernier jour du plan — l'avant-dernière information d'un calendrier. */
export function lastDayOf(anchor: string, weeksCount: number): string {
  return dateOfSlot(anchor, weeksCount, 7);
}

/**
 * L'état d'une case, déduit — jamais stocké.
 *
 * Six états, dont un seul dépend d'une écriture (`done`, qui découle du
 * lien séance → jour) :
 *  - `free` : aucune case n'occupe ce jour, rien n'était prévu ;
 *  - `rest` : repos EXPLICITEMENT planifié, ce qui n'est pas pareil ;
 *  - `done` : une séance TERMINÉE porte l'identifiant de cette case ;
 *  - `before` : la case précède le départ réel (semaine 1 d'un départ en
 *    milieu de semaine) ;
 *  - `missed` : la date est passée et rien n'a été fait ;
 *  - `upcoming` : tout le reste, c'est-à-dire aujourd'hui et l'avenir.
 *
 * `today` est le jour civil DANS LE FUSEAU DE LA PERSONNE : une séance du
 * mardi soir à Paris ne devient pas « manquée » parce qu'il est déjà
 * mercredi à Greenwich.
 */
export function statusOfSlot(input: {
  date: string;
  /** `false` quand aucune case n'occupe ce jour : rien n'était prévu. */
  planned: boolean;
  isRest: boolean;
  done: boolean;
  startsOn: string;
  today: string;
}): ProgramDayStatus {
  if (!input.planned) return 'free';
  if (input.isRest) return 'rest';
  if (input.done) return 'done';
  if (input.date < input.startsOn) return 'before';
  if (input.date < input.today) return 'missed';
  return 'upcoming';
}

/**
 * Le jour de la semaine d'une date, dans la numérotation du programme.
 *
 * Réexporté ici pour que le module de calendrier n'ait qu'une porte
 * d'entrée : la grille et les jours civils se parlent à cet endroit, et
 * nulle part ailleurs.
 */
export { isoWeekday };

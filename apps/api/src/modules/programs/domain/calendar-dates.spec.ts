import {
  addDays,
  daysBetween,
  isDayKey,
  isoWeekday,
  mondayOf,
} from '../../../common/utilities/civil-day';
import { anchorOf, dateOfSlot, lastDayOf, statusOfSlot, weekOfDate } from './calendar-dates';

/**
 * CE QUE CE FICHIER PROTÈGE : la date d'une case, et ce qu'elle autorise à
 * dire de son état.
 *
 * Tout ici est de l'arithmétique de JOURS CIVILS — jamais d'instants. Un
 * calcul qui passe par un fuseau se trompe deux fois par an, et une seule
 * fois suffit pour peindre en rouge une séance faite.
 */
describe('jours civils', () => {
  it('avance et recule sans se faire piéger par l’heure d’été', () => {
    // Le dernier dimanche de mars, l'Europe perd une heure. Une arithmétique
    // en millisecondes depuis MINUIT y saute un jour ; depuis midi, non.
    expect(addDays('2026-03-28', 1)).toBe('2026-03-29');
    expect(addDays('2026-03-29', 1)).toBe('2026-03-30');
    expect(addDays('2026-10-25', -1)).toBe('2026-10-24');
    // Et les bascules de mois, d'année et les années bissextiles.
    expect(addDays('2026-02-28', 1)).toBe('2026-03-01');
    expect(addDays('2028-02-28', 1)).toBe('2028-02-29');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
  });

  it('compte les jours entre deux dates, dans les deux sens', () => {
    expect(daysBetween('2026-09-21', '2026-09-28')).toBe(7);
    expect(daysBetween('2026-09-28', '2026-09-21')).toBe(-7);
    expect(daysBetween('2026-09-21', '2026-09-21')).toBe(0);
    // À cheval sur le changement d'heure : sept jours restent sept jours.
    expect(daysBetween('2026-10-22', '2026-10-29')).toBe(7);
  });

  it('numérote les jours comme le programme : 1 = lundi, 7 = dimanche', () => {
    expect(isoWeekday('2026-09-21')).toBe(1);
    expect(isoWeekday('2026-09-27')).toBe(7);
    expect(mondayOf('2026-09-23')).toBe('2026-09-21');
    // Un lundi est son propre lundi.
    expect(mondayOf('2026-09-21')).toBe('2026-09-21');
    // Et un dimanche appartient à la semaine qui l'a précédé.
    expect(mondayOf('2026-09-27')).toBe('2026-09-21');
  });

  it('refuse un jour qui n’existe pas, plutôt que de le corriger', () => {
    expect(isDayKey('2026-09-21')).toBe(true);
    // `new Date('2026-02-31')` rend le 3 mars sans se plaindre : une date
    // corrigée en douce est pire qu'un refus.
    expect(isDayKey('2026-02-31')).toBe(false);
    expect(isDayKey('2026-13-01')).toBe(false);
    expect(isDayKey('21/09/2026')).toBe(false);
    expect(isDayKey(null)).toBe(false);
  });
});

describe('la date d’une case', () => {
  it('ancre la grille au LUNDI, même si le plan commence un mercredi', () => {
    const anchor = anchorOf('2026-09-23');
    expect(anchor).toBe('2026-09-21');
    // Semaine 1, mercredi : le jour du départ lui-même.
    expect(dateOfSlot(anchor, 1, 3)).toBe('2026-09-23');
    // Semaine 2, lundi : sept jours plus tard.
    expect(dateOfSlot(anchor, 2, 1)).toBe('2026-09-28');
    expect(lastDayOf(anchor, 4)).toBe('2026-10-18');
  });

  it('retrouve la semaine d’une date, et sort du plan quand il est fini', () => {
    const anchor = anchorOf('2026-09-21');
    expect(weekOfDate(anchor, 4, '2026-09-21')).toBe(1);
    expect(weekOfDate(anchor, 4, '2026-09-27')).toBe(1);
    expect(weekOfDate(anchor, 4, '2026-09-28')).toBe(2);
    expect(weekOfDate(anchor, 4, '2026-10-18')).toBe(4);
    // Après la fin, et avant le début : hors du plan dans les deux cas.
    expect(weekOfDate(anchor, 4, '2026-10-19')).toBeNull();
    expect(weekOfDate(anchor, 4, '2026-09-20')).toBeNull();
  });
});

describe('l’état d’une case', () => {
  const base = { startsOn: '2026-09-23', today: '2026-09-28' };

  it('« libre » quand rien n’était prévu, « repos » quand le repos l’était', () => {
    // Les deux se ressemblent à l'écran et ne disent pas la même chose : le
    // repos est une décision du plan, le jour libre une absence de décision.
    expect(
      statusOfSlot({ ...base, date: '2026-09-25', planned: false, isRest: false, done: false }),
    ).toBe('free');
    expect(
      statusOfSlot({ ...base, date: '2026-09-25', planned: true, isRest: true, done: false }),
    ).toBe('rest');
  });

  it('ne déclare jamais manqués les jours d’AVANT le départ', () => {
    // Commencer un mercredi laisse lundi et mardi derrière soi. Sans cette
    // nuance, la première ouverture du calendrier accueillerait par deux
    // cases rouges des séances que personne n'avait promis de faire.
    expect(
      statusOfSlot({ ...base, date: '2026-09-21', planned: true, isRest: false, done: false }),
    ).toBe('before');
    expect(
      statusOfSlot({ ...base, date: '2026-09-22', planned: true, isRest: false, done: false }),
    ).toBe('before');
  });

  it('manque une séance passée, attend une séance à venir', () => {
    expect(
      statusOfSlot({ ...base, date: '2026-09-24', planned: true, isRest: false, done: false }),
    ).toBe('missed');
    // AUJOURD'HUI n'est pas manqué : la journée n'est pas finie.
    expect(
      statusOfSlot({ ...base, date: '2026-09-28', planned: true, isRest: false, done: false }),
    ).toBe('upcoming');
    expect(
      statusOfSlot({ ...base, date: '2026-09-30', planned: true, isRest: false, done: false }),
    ).toBe('upcoming');
  });

  it('« fait » l’emporte sur la date, jamais l’inverse', () => {
    // Une séance faite en retard reste faite : c'est le lien qui compte, pas
    // le calendrier.
    expect(
      statusOfSlot({ ...base, date: '2026-09-24', planned: true, isRest: false, done: true }),
    ).toBe('done');
  });
});

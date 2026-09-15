import { isIanaTimeZone, safeTimeZone } from './time-zone';

/**
 * Ce que ce fichier protège : le fuseau qui sort d'ici part dans une requête
 * `AT TIME ZONE`. PostgreSQL refuse un fuseau inconnu, donc une chaîne
 * fantaisiste laissée passer transformerait une lecture de statistiques en
 * erreur 500.
 */
describe('fuseaux horaires IANA', () => {
  it('reconnaît de vrais fuseaux', () => {
    for (const zone of ['Europe/Paris', 'America/Montreal', 'UTC', 'Asia/Tokyo']) {
      expect(isIanaTimeZone(zone)).toBe(true);
    }
  });

  it('refuse ce qui y ressemble sans en être', () => {
    // « Europe/Pariss » est exactement le genre de chose qu'une expression
    // régulière maison laisserait passer : c'est ICU qui tranche, pas une
    // forme.
    for (const faux of ['Europe/Pariss', 'Paris', 'UTC+1', '', '  ', 'DROP TABLE']) {
      expect(isIanaTimeZone(faux)).toBe(false);
    }
  });

  it('refuse ce qui n’est pas une chaîne', () => {
    for (const faux of [null, undefined, 42, {}, []]) {
      expect(isIanaTimeZone(faux)).toBe(false);
    }
  });

  it('se replie sur UTC plutôt que de laisser passer l’invalide', () => {
    // Une colonne écrite avant que la validation n'existe peut contenir
    // n'importe quoi : mieux vaut un découpage UTC, visiblement décalé mais
    // lisible, qu'une page d'erreur.
    expect(safeTimeZone('Europe/Paris')).toBe('Europe/Paris');
    expect(safeTimeZone('n’importe quoi')).toBe('UTC');
    expect(safeTimeZone(null)).toBe('UTC');
  });
});

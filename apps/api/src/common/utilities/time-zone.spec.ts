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

  it('reconnaît les ALIAS que les téléphones renvoient vraiment', () => {
    // C'est l'intérêt de canoniser plutôt que de comparer à la liste telle
    // quelle : `US/Pacific` devient `America/Los_Angeles`, `Asia/Kolkata`
    // devient `Asia/Calcutta`, `Europe/Kiev` existe encore. Les refuser
    // condamnerait des appareils parfaitement réglés.
    for (const alias of ['US/Pacific', 'Asia/Kolkata', 'Europe/Kiev', 'Etc/UTC', 'Etc/GMT+5']) {
      expect(isIanaTimeZone(alias)).toBe(true);
    }
  });

  it('refuse les DÉCALAGES BRUTS, qu’ICU accepte pourtant', () => {
    // LE DÉFAUT. `new Intl.DateTimeFormat(…, { timeZone: '+05:30' })` ne lève
    // PAS depuis ICU 72 — mesuré sur Node 22, la version du dépôt. Le
    // contrôle se résumait à cette absence de levée : n'importe quel client
    // pouvait donc écrire `{"timezone":"+05:30"}`, la valeur atteignait la
    // colonne, `safeTimeZone` la réacceptait, et elle partait telle quelle
    // dans `AT TIME ZONE`. Le message du décorateur promet pourtant
    // « identifiant IANA attendu, ex. Europe/Paris ».
    for (const decalage of ['+05:30', '+0530', '-08:00', '+05', '-0800']) {
      expect(isIanaTimeZone(decalage)).toBe(false);
    }
  });

  it('refuse ce qui y ressemble sans en être', () => {
    // « Europe/Pariss » est exactement le genre de chose qu'une expression
    // régulière maison laisserait passer : c'est ICU qui tranche, pas une
    // forme.
    for (const faux of [
      'Europe/Pariss',
      'Paris',
      'UTC+1',
      '',
      '  ',
      'DROP TABLE',
      'GMT+02:00',
      'Etc/Unknown',
    ]) {
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
    // Une colonne écrite AVANT le durcissement peut porter un décalage brut :
    // le repli doit l'attraper, puisque c'est lui qui alimente `AT TIME ZONE`.
    expect(safeTimeZone('+05:30')).toBe('UTC');
    // Et le repli lui-même doit rester valide — `UTC` n'est pas dans
    // `Intl.supportedValuesOf('timeZone')`, ce qui est exactement le piège.
    expect(isIanaTimeZone(safeTimeZone(null))).toBe(true);
  });
});

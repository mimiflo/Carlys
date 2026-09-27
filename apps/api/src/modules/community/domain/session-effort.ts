import { WORKOUT_LIMITS } from '@carlys/api-contracts';

/**
 * BORNES DE PLAUSIBILITÉ de ce qu'une séance verse aux défis et à la ligue.
 *
 * L'effort est DÉCLARATIF par conception : l'appli n'a ni GPS ni capteur, et
 * une série dit elle-même sa distance et sa durée. Rien ne le prouve ; on
 * peut en revanche refuser l'impossible. Mesuré avant ces bornes : une
 * séance VIDE, ouverte puis close depuis l'interface normale, valait 50
 * points ; une séance d'une minute portant une série de 1 000 km et 24 h en
 * valait 11 540 — là où une semaine régulière vaut 150 à 400 points
 * (docs/product/community.md). Un seul membre écrasait son groupe chaque
 * semaine, et les défis entre amis et le jeu du mois, qui passent par la
 * même couture, avec lui.
 *
 * Ces bornes ne touchent QUE ce qui est crédité aux défis et à la ligue. La
 * séance, ses séries et les records restent tels que la personne les a
 * saisis : ce sont ses données, pas un classement.
 *
 * CE QU'ELLES LAISSENT, mesuré (revue de septembre 2026) : un client forgé
 * qui déclare une séance de 24 h et 300 km en tire 4 490 points (50 + 1 440
 * + 3 000), et 21 séances créditées par semaine (3 par jour) vont jusqu'à
 * 94 272. Des plafonds hebdomadaires borneraient ce total, pas le RANG, qui
 * est la seule chose qu'une ligue récompense ; et compter le plafond du jour
 * à l'heure du serveur ne créditerait que trois séances d'une semaine hors
 * ligne synchronisée d'un coup. L'effort reste déclaratif : c'est le prix
 * d'une appli sans capteur, pas un oubli.
 */

/** Distance créditée au plus pour une séance : 300 km, déjà un ultra. */
export const MAX_CREDITED_DISTANCE_METERS = 300_000;

/**
 * Vitesse moyenne plausible au plus sur toute la séance : 20 m/s (72 km/h),
 * au-dessus d'une sortie vélo rapide. Une séance d'une minute ne crédite
 * donc pas plus de 1,2 km.
 */
export const MAX_PLAUSIBLE_SPEED_METERS_PER_SECOND = 20;

/**
 * Séances qui comptent, par personne et par jour UTC (de clôture). Au-delà,
 * la séance est enregistrée comme les autres mais ne verse plus rien : ouvrir
 * et clore des séances en boucle ne remplit plus un classement.
 */
export const SESSIONS_CREDITED_PER_DAY = 3;

/** Ce qu'une séance a coûté, d'après ses séries et son créneau. */
export interface DeclaredSessionEffort {
  /** Séries non supprimées. */
  setsCount: number;
  /** Somme des durées déclarées série par série. */
  activeSeconds: number;
  /** Somme des distances déclarées série par série. */
  distanceMeters: number;
  /** Du début à la fin de la séance, tel qu'enregistré. */
  windowSeconds: number;
  /** Séances TERMINÉES ce jour-là, celle-ci comprise. */
  completedThatDay: number;
}

/**
 * Ce qu'une séance verse aux défis et à la ligue, dans les unités que ceux-ci
 * savent compter. Voir `creditedEffort`.
 */
export interface SessionEffort {
  /** La séance compte-t-elle comme UNE séance (métrique WORKOUTS) ? */
  countsAsWorkout: boolean;
  /** Secondes réellement chronométrées série par série, pauses exclues. */
  activeSeconds: number;
  distanceMeters: number;
}

/** Rien du tout : une séance au-delà du plafond du jour. */
export const NO_EFFORT: SessionEffort = {
  countsAsWorkout: false,
  activeSeconds: 0,
  distanceMeters: 0,
};

/**
 * L'effort CRÉDITÉ d'une séance, borné à ce qui est physiquement possible :
 *  - une séance SANS série ne compte pas comme une séance ;
 *  - le temps d'effort ne dépasse pas le créneau de la séance (lui-même
 *    borné à `WORKOUT_LIMITS.durationSecondsMax`) ;
 *  - la distance ne dépasse ni 300 km, ni ce qu'une vitesse moyenne de
 *    72 km/h couvre sur ce créneau ;
 *  - au-delà de `SESSIONS_CREDITED_PER_DAY` séances le même jour, rien.
 */
export function creditedEffort(declared: DeclaredSessionEffort): SessionEffort {
  if (declared.completedThatDay > SESSIONS_CREDITED_PER_DAY) {
    return NO_EFFORT;
  }
  // En secondes ENTIÈRES : le créneau vient de deux horodatages à la
  // milliseconde, et les compteurs qui le reçoivent ne s'accordent pas sur
  // une fraction (Prisma tronque 600,5 en 600, un `::int` SQL l'arrondit à
  // 601) — le même effort valait une seconde de plus à un défi qu'à l'autre.
  const window = Math.floor(
    Math.max(0, Math.min(declared.windowSeconds, WORKOUT_LIMITS.durationSecondsMax)),
  );
  return {
    countsAsWorkout: declared.setsCount > 0,
    activeSeconds: Math.min(Math.max(0, declared.activeSeconds), window),
    distanceMeters: Math.min(
      Math.max(0, declared.distanceMeters),
      MAX_CREDITED_DISTANCE_METERS,
      Math.floor(window * MAX_PLAUSIBLE_SPEED_METERS_PER_SECOND),
    ),
  };
}

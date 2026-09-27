import { type SessionEffort } from '../../community/application/community-challenges.service';
import { creditedEffort } from '../../community/domain/session-effort';
import {
  type SessionWithSets,
  type WorkoutsRepository,
} from '../infrastructure/workouts.repository';

/**
 * Ce qu'une séance a coûté en TEMPS et en DISTANCE, d'après ses séries —
 * AVANT les bornes de plausibilité (`creditedEffort`, domaine communauté).
 *
 * Volontairement ailleurs que dans la durée de la séance : `durationSeconds`
 * mesure du début à la fin, pauses et rangement compris, alors que ces
 * secondes-ci sont celles qu'on a réellement chronométrées série par série.
 * Un défi qui compte des secondes d'effort ne doit pas créditer le temps
 * passé à discuter entre deux séries. Les séries sans chrono ni distance —
 * la fonte, l'immense majorité — apportent zéro, ce qui est exact.
 */
export function declaredEffort(sets: SessionWithSets['sets']): {
  activeSeconds: number;
  distanceMeters: number;
} {
  return sets.reduce(
    (total, set) => ({
      activeSeconds: total.activeSeconds + (set.durationSeconds ?? 0),
      distanceMeters: total.distanceMeters + (set.distanceMeters ?? 0),
    }),
    { activeSeconds: 0, distanceMeters: 0 },
  );
}

/**
 * L'effort que les défis et la ligue retiennent d'une séance qu'on vient de
 * clore : ses séries (non supprimées), bornées par son créneau, et rien
 * au-delà du plafond de séances créditées ce jour-là (jour UTC de la fin).
 */
export async function creditedSessionEffort(
  workouts: WorkoutsRepository,
  userId: string,
  closed: SessionWithSets,
  endedAt: Date,
): Promise<SessionEffort> {
  const dayStart = new Date(endedAt);
  dayStart.setUTCHours(0, 0, 0, 0);
  const completedThatDay = await workouts.countCompletedEndedBetween(
    userId,
    dayStart,
    new Date(dayStart.getTime() + 24 * 3_600_000),
  );
  return creditedEffort({
    setsCount: closed.sets.length,
    ...declaredEffort(closed.sets),
    windowSeconds: (endedAt.getTime() - closed.startedAt.getTime()) / 1_000,
    completedThatDay,
  });
}

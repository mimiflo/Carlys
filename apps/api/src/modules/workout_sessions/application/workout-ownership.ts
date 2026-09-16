import { NotFoundException } from '@nestjs/common';
import { type WorkoutSession, type WorkoutSet } from '@prisma/client';
import {
  type SessionWithSets,
  type WorkoutsRepository,
} from '../infrastructure/workouts.repository';

/**
 * Gardes d'appartenance des séances et des séries.
 *
 * Partagées par les deux services du module (séances et séries) : la règle
 * « ne rien révéler de ce qui appartient à autrui » ne doit exister qu'à un
 * seul endroit, sans quoi une des deux moitiés finirait par répondre 403 là
 * où l'autre répond 404.
 */

/** Séance de l'utilisateur, ou 404 — y compris quand elle est à quelqu'un d'autre. */
export async function ownedSession(
  workouts: WorkoutsRepository,
  userId: string,
  sessionId: string,
): Promise<SessionWithSets> {
  const session = await workouts.findSessionById(sessionId);
  if (session === null) {
    throw new NotFoundException('Séance introuvable.');
  }
  if (session.userId !== userId) {
    // Même réponse qu'un 404 : ne pas révéler l'existence d'autrui.
    throw new NotFoundException('Séance introuvable.');
  }
  return session;
}

/**
 * Série de l'utilisateur, encore vivante, ou 404.
 *
 * Elle est RENDUE plutôt que seulement vérifiée : l'appelant a besoin de son
 * exercice et du statut de sa séance pour savoir s'il doit recalculer les
 * records, et la lecture a déjà eu lieu ici.
 */
export async function ownedSet(
  workouts: WorkoutsRepository,
  userId: string,
  setId: string,
): Promise<WorkoutSet & { session: WorkoutSession }> {
  const set = await workouts.findSetById(setId);
  if (set === null || set.session.userId !== userId || set.deletedAt !== null) {
    throw new NotFoundException('Série introuvable.');
  }
  return set;
}

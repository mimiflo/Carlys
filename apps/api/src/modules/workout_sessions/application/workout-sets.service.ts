import { type WorkoutSet as WorkoutSetContract } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { WorkoutSetKind } from '@prisma/client';
import { WorkoutsRepository } from '../infrastructure/workouts.repository';
import { ownedSession, ownedSet } from './workout-ownership';
import { presentSet } from './workout.presenter';

export interface CreateSetInput {
  id: string;
  exerciseId?: string;
  exerciseName?: string;
  position: number;
  kind?: WorkoutSetKind;
  reps?: number;
  weightKg?: number;
  durationSeconds?: number;
  distanceMeters?: number;
  rpe?: number;
  restSeconds?: number;
  /** Cible AFFICHÉE au moment de la validation — fait historique figé. */
  plannedReps?: number;
  plannedWeightKg?: number;
  /** Prévision du plan que cette série honore, s'il y en a une. */
  planItemId?: string;
  completedAt: Date;
}

/**
 * Les SÉRIES d'une séance : le fait réalisé, rejouable à volonté.
 *
 * Séparé des séances parce que le cycle de vie n'est pas le même : une séance
 * s'ouvre, se clôt et déclenche records et défis ; une série s'ajoute, se
 * corrige et se supprime, et ne doit JAMAIS échouer pour une raison
 * accessoire (catalogue muet, plan désaccordé, rejeu du même envoi).
 */
@Injectable()
export class WorkoutSetsService {
  constructor(private readonly workouts: WorkoutsRepository) {}

  /** Upsert idempotent d'une série (id généré sur l'appareil). */
  async addSet(
    userId: string,
    sessionId: string,
    input: CreateSetInput,
  ): Promise<WorkoutSetContract> {
    const session = await ownedSession(this.workouts, userId, sessionId);

    const existing = await this.workouts.findSetById(input.id);
    if (existing !== null) {
      if (existing.sessionId !== sessionId || existing.session.userId !== userId) {
        throw new ConflictException('Identifiant de série déjà utilisé.');
      }
      // Rejeu : la série est là, mais l'appariement au plan a pu manquer si le
      // premier envoi s'est interrompu entre les deux écritures. On le refait,
      // il est idempotent.
      await this.linkPlanItem(sessionId, input);
      return presentSet(existing);
    }

    const exerciseName = await this.resolveExerciseName(input);

    const created = await this.workouts.createSet({
      id: input.id,
      sessionId: session.id,
      exerciseId: input.exerciseId ?? null,
      exerciseName,
      position: input.position,
      kind: input.kind ?? WorkoutSetKind.NORMAL,
      reps: input.reps ?? null,
      weightKg: input.weightKg ?? null,
      durationSeconds: input.durationSeconds ?? null,
      distanceMeters: input.distanceMeters ?? null,
      rpe: input.rpe ?? null,
      restSeconds: input.restSeconds ?? null,
      plannedReps: input.plannedReps ?? null,
      plannedWeightKg: input.plannedWeightKg ?? null,
      completedAt: input.completedAt,
    });
    if (!created) {
      // Course entre deux rejeux : l'autre écriture a gagné, on la sert.
      const replayed = await this.workouts.findSetById(input.id);
      if (replayed === null || replayed.sessionId !== sessionId) {
        throw new ConflictException('Identifiant de série déjà utilisé.');
      }
      await this.linkPlanItem(sessionId, input);
      return presentSet(replayed);
    }
    await this.linkPlanItem(sessionId, input);
    const stored = await this.workouts.findSetById(input.id);
    if (stored === null) {
      throw new NotFoundException('Série introuvable.');
    }
    return presentSet(stored);
  }

  /**
   * Marque la prévision honorée par cette série. Un `planItemId` inconnu, déjà
   * honoré ou appartenant à une autre séance est simplement ignoré : la série
   * est le fait, l'appariement n'est qu'un confort d'affichage et ne doit
   * jamais faire échouer son enregistrement.
   */
  private async linkPlanItem(sessionId: string, input: CreateSetInput): Promise<void> {
    if (input.planItemId === undefined) {
      return;
    }
    await this.workouts.linkPlanItem(sessionId, input.planItemId, input.id);
  }

  /**
   * Corriger une série, c'est corriger le FAIT réalisé : la cible affichée à
   * l'instant de la validation (`planned*`) n'est jamais réécrivable.
   */
  async updateSet(
    userId: string,
    setId: string,
    data: Partial<
      Omit<
        CreateSetInput,
        'id' | 'exerciseId' | 'exerciseName' | 'position' | 'plannedReps' | 'plannedWeightKg'
      >
    >,
  ): Promise<WorkoutSetContract> {
    await ownedSet(this.workouts, userId, setId);
    const updated = await this.workouts.updateSet(setId, {
      ...(data.kind === undefined ? {} : { kind: data.kind }),
      ...(data.reps === undefined ? {} : { reps: data.reps }),
      ...(data.weightKg === undefined ? {} : { weightKg: data.weightKg }),
      ...(data.durationSeconds === undefined ? {} : { durationSeconds: data.durationSeconds }),
      ...(data.distanceMeters === undefined ? {} : { distanceMeters: data.distanceMeters }),
      ...(data.rpe === undefined ? {} : { rpe: data.rpe }),
      ...(data.restSeconds === undefined ? {} : { restSeconds: data.restSeconds }),
      ...(data.completedAt === undefined ? {} : { completedAt: data.completedAt }),
    });
    return presentSet(updated);
  }

  /** Idempotent : supprimer une série déjà supprimée est un succès. */
  async deleteSet(userId: string, setId: string): Promise<void> {
    const set = await this.workouts.findSetById(setId);
    if (set === null || set.session.userId !== userId) {
      // Inconnue ou pas à soi : ne rien révéler, le rejeu d'une suppression
      // déjà propagée doit aboutir.
      if (set !== null) {
        throw new NotFoundException('Série introuvable.');
      }
      return;
    }
    if (set.deletedAt !== null) {
      return;
    }
    await this.workouts.softDeleteSet(setId);
  }

  /**
   * Le nom du catalogue fait foi ; à défaut, celui transmis par l'appareil.
   * Sans l'un ni l'autre, la série n'a pas de sujet et la requête est refusée.
   */
  private async resolveExerciseName(input: CreateSetInput): Promise<string> {
    if (input.exerciseId !== undefined) {
      const name = await this.workouts.exercisePublishedName(input.exerciseId);
      if (name !== null) {
        return name;
      }
    }
    const fallback = input.exerciseName?.trim();
    if (fallback === undefined || fallback.length === 0) {
      throw new BadRequestException('exerciseId inconnu et exerciseName absent.');
    }
    return fallback;
  }
}

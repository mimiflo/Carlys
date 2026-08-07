import {
  type WorkoutSessionDetail,
  type WorkoutSessionSummary,
  type WorkoutSet as WorkoutSetContract,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { WorkoutSessionStatus, WorkoutSetKind } from '@prisma/client';
import { type SessionWithSets, WorkoutsRepository } from '../infrastructure/workouts.repository';
import { presentSessionDetail, presentSessionSummary, presentSet } from './workout.presenter';

export interface CreateSessionInput {
  id: string;
  name?: string;
  notes?: string;
  startedAt: Date;
}

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
  completedAt: Date;
}

export interface SessionsPage {
  items: WorkoutSessionSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

/**
 * Séances offline-first : les identifiants viennent de l'appareil et chaque
 * écriture est REJOUABLE — renvoyer la même requête ne crée jamais de doublon.
 */
@Injectable()
export class WorkoutsService {
  constructor(private readonly workouts: WorkoutsRepository) {}

  async createSession(userId: string, input: CreateSessionInput): Promise<WorkoutSessionDetail> {
    const created = await this.workouts.createSession({
      id: input.id,
      userId,
      name: input.name ?? null,
      notes: input.notes ?? null,
      startedAt: input.startedAt,
    });
    if (!created) {
      // Rejeu : l'id existe déjà — il doit appartenir au même utilisateur.
      return presentSessionDetail(await this.ownedSession(userId, input.id));
    }
    return presentSessionDetail(await this.ownedSession(userId, input.id));
  }

  async listSessions(userId: string, limit: number, cursor?: string): Promise<SessionsPage> {
    const rows = await this.workouts.listSessionsPage(userId, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map(presentSessionSummary);
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
  }

  async sessionDetail(userId: string, sessionId: string): Promise<WorkoutSessionDetail> {
    return presentSessionDetail(await this.ownedSession(userId, sessionId));
  }

  async updateSession(
    userId: string,
    sessionId: string,
    data: { name?: string; notes?: string },
  ): Promise<WorkoutSessionDetail> {
    await this.ownedSession(userId, sessionId);
    const updated = await this.workouts.updateSession(sessionId, {
      ...(data.name === undefined ? {} : { name: data.name }),
      ...(data.notes === undefined ? {} : { notes: data.notes }),
    });
    return presentSessionDetail(updated);
  }

  /** Idempotent : re-clôturer une séance déjà terminée renvoie son état. */
  async completeSession(
    userId: string,
    sessionId: string,
    input: { endedAt?: Date; durationSeconds?: number },
  ): Promise<WorkoutSessionDetail> {
    return this.closeSession(userId, sessionId, WorkoutSessionStatus.COMPLETED, input);
  }

  async abandonSession(
    userId: string,
    sessionId: string,
    input: { endedAt?: Date },
  ): Promise<WorkoutSessionDetail> {
    return this.closeSession(userId, sessionId, WorkoutSessionStatus.ABANDONED, input);
  }

  /** Upsert idempotent d'une série (id généré sur l'appareil). */
  async addSet(
    userId: string,
    sessionId: string,
    input: CreateSetInput,
  ): Promise<WorkoutSetContract> {
    const session = await this.ownedSession(userId, sessionId);

    const existing = await this.workouts.findSetById(input.id);
    if (existing !== null) {
      if (existing.sessionId !== sessionId || existing.session.userId !== userId) {
        throw new ConflictException('Identifiant de série déjà utilisé.');
      }
      return presentSet(existing); // rejeu
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
      completedAt: input.completedAt,
    });
    if (!created) {
      // Course entre deux rejeux : l'autre écriture a gagné, on la sert.
      const replayed = await this.workouts.findSetById(input.id);
      if (replayed === null || replayed.sessionId !== sessionId) {
        throw new ConflictException('Identifiant de série déjà utilisé.');
      }
      return presentSet(replayed);
    }
    const stored = await this.workouts.findSetById(input.id);
    if (stored === null) {
      throw new NotFoundException('Série introuvable.');
    }
    return presentSet(stored);
  }

  async updateSet(
    userId: string,
    setId: string,
    data: Partial<Omit<CreateSetInput, 'id' | 'exerciseId' | 'exerciseName' | 'position'>>,
  ): Promise<WorkoutSetContract> {
    await this.ownedSet(userId, setId);
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

  private async closeSession(
    userId: string,
    sessionId: string,
    to: WorkoutSessionStatus,
    input: { endedAt?: Date; durationSeconds?: number },
  ): Promise<WorkoutSessionDetail> {
    const session = await this.ownedSession(userId, sessionId);

    if (session.status === to) {
      return presentSessionDetail(session); // rejeu
    }
    if (session.status !== WorkoutSessionStatus.IN_PROGRESS) {
      // Clôturée avec un AUTRE statut : conflit réel, pas un rejeu.
      throw new ConflictException('La séance est déjà clôturée.');
    }

    const endedAt = input.endedAt ?? new Date();
    const durationSeconds =
      input.durationSeconds ??
      Math.max(0, Math.round((endedAt.getTime() - session.startedAt.getTime()) / 1_000));

    const transitioned = await this.workouts.transitionStatus(sessionId, to, {
      endedAt,
      durationSeconds,
    });
    if (!transitioned) {
      // Déjà clôturée avec un AUTRE statut : conflit réel, pas un rejeu.
      throw new ConflictException('La séance est déjà clôturée.');
    }
    return presentSessionDetail(await this.ownedSession(userId, sessionId));
  }

  private async ownedSession(userId: string, sessionId: string): Promise<SessionWithSets> {
    const session = await this.workouts.findSessionById(sessionId);
    if (session === null) {
      throw new NotFoundException('Séance introuvable.');
    }
    if (session.userId !== userId) {
      // Même réponse qu'un 404 : ne pas révéler l'existence d'autrui.
      throw new NotFoundException('Séance introuvable.');
    }
    return session;
  }

  private async ownedSet(userId: string, setId: string): Promise<void> {
    const set = await this.workouts.findSetById(setId);
    if (set === null || set.session.userId !== userId || set.deletedAt !== null) {
      throw new NotFoundException('Série introuvable.');
    }
  }

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

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
import { type Prisma, WorkoutSessionStatus, WorkoutSetKind } from '@prisma/client';
import { CommunityService } from '../../community/application/community.service';
import { ProgressService } from '../../progress/application/progress.service';
import { WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { type SessionWithSets, WorkoutsRepository } from '../infrastructure/workouts.repository';
import { presentSessionDetail, presentSessionSummary, presentSet } from './workout.presenter';

/** Série prévue transmise au lancement — des cibles, pas des mesures. */
export interface CreateSessionPlanItemInput {
  id: string;
  exercisePosition: number;
  exerciseId?: string;
  exerciseName: string;
  setPosition: number;
  kind?: WorkoutSetKind;
  targetReps?: number;
  targetWeightKg?: number;
  restSeconds?: number;
}

export interface CreateSessionInput {
  id: string;
  name?: string;
  notes?: string;
  startedAt: Date;
  /** Modèle lancé — facultatif, et jamais bloquant s'il est inconnu. */
  templateId?: string;
  /** Nom du modèle conservé par le client, utilisé en secours. */
  templateName?: string;
  /**
   * Plan de la séance, copié du modèle par l'appareil au lancement. Absent
   * pour une séance libre. Transmis À LA CRÉATION et jamais ensuite : c'est
   * ce qui permet de reprendre la séance sur un autre appareil.
   */
  plan?: CreateSessionPlanItemInput[];
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
  /** Cible AFFICHÉE au moment de la validation — fait historique figé. */
  plannedReps?: number;
  plannedWeightKg?: number;
  /** Prévision du plan que cette série honore, s'il y en a une. */
  planItemId?: string;
  completedAt: Date;
}

type PlanItemRow = Prisma.WorkoutSessionPlanItemUncheckedCreateInput;

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
  constructor(
    private readonly workouts: WorkoutsRepository,
    private readonly progress: ProgressService,
    private readonly community: CommunityService,
    private readonly templates: WorkoutTemplatesService,
  ) {}

  /**
   * La création NE PEUT PAS échouer à cause du modèle : un `templateId`
   * inconnu, supprimé ou appartenant à autrui est simplement ignoré, le nom
   * conservé par le client prenant le relais. Aucune séance n'est perdue.
   */
  async createSession(userId: string, input: CreateSessionInput): Promise<WorkoutSessionDetail> {
    const origin = await this.templates.resolveSessionOrigin(userId, {
      ...(input.templateId === undefined ? {} : { templateId: input.templateId }),
      ...(input.templateName === undefined ? {} : { templateName: input.templateName }),
    });
    await this.workouts.createSession(
      {
        id: input.id,
        userId,
        name: input.name ?? null,
        notes: input.notes ?? null,
        startedAt: input.startedAt,
        templateId: origin.templateId,
        templateName: origin.templateName,
      },
      origin.templateId === null
        ? undefined
        : { templateId: origin.templateId, userId, lastUsedAt: input.startedAt },
      await this.buildPlanRows(input.id, input.plan ?? []),
    );
    // Créée ou rejouée : dans les deux cas on sert l'état stocké, qui doit
    // appartenir au même utilisateur.
    return presentSessionDetail(await this.ownedSession(userId, input.id));
  }

  /**
   * Prépare les lignes du plan. Comme pour les modèles, un `exerciseId`
   * inconnu ou dépublié dégrade la prévision en exercice LIBRE (clé étrangère
   * nulle, nom dénormalisé conservé) au lieu de faire échouer la requête :
   * une séance ne se perd jamais à cause du catalogue.
   */
  private async buildPlanRows(
    sessionId: string,
    plan: CreateSessionPlanItemInput[],
  ): Promise<PlanItemRow[]> {
    const catalogNames = await this.workouts.publishedExerciseNames(
      plan.flatMap((item) => (item.exerciseId === undefined ? [] : [item.exerciseId])),
    );

    return plan.map((item) => {
      const catalogName =
        item.exerciseId === undefined ? undefined : catalogNames.get(item.exerciseId);
      return {
        id: item.id,
        sessionId,
        exercisePosition: item.exercisePosition,
        exerciseId: catalogName === undefined ? null : (item.exerciseId ?? null),
        exerciseName: catalogName ?? item.exerciseName,
        setPosition: item.setPosition,
        kind: item.kind ?? WorkoutSetKind.NORMAL,
        targetReps: item.targetReps ?? null,
        targetWeightKg: item.targetWeightKg ?? null,
        restSeconds: item.restSeconds ?? null,
      };
    });
  }

  /**
   * Passe des prévisions du plan. Idempotent : rejouer la même liste répond
   * la même chose, et une prévision déjà honorée par une série n'est jamais
   * repassée en « sautée ».
   */
  async skipPlanItems(
    userId: string,
    sessionId: string,
    planItemIds: string[],
  ): Promise<WorkoutSessionDetail> {
    await this.ownedSession(userId, sessionId);
    await this.workouts.skipPlanItems(sessionId, planItemIds);
    return presentSessionDetail(await this.ownedSession(userId, sessionId));
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
    const closed = await this.ownedSession(userId, sessionId);
    if (to === WorkoutSessionStatus.COMPLETED) {
      // Aucun des deux ne fait échouer la clôture : chacun journalise
      // ses erreurs et se rattrape à la séance suivante.
      await this.progress.updateRecordsForSession(userId, sessionId, closed.sets);
      await this.community.recordWorkoutCompleted(userId, endedAt);
    }
    return presentSessionDetail(closed);
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

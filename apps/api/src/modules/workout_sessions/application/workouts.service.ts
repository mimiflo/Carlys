import { type WorkoutSessionDetail, type WorkoutSessionSummary } from '@carlys/api-contracts';
import { ConflictException, Injectable } from '@nestjs/common';
import { type Prisma, WorkoutSessionStatus, WorkoutSetKind } from '@prisma/client';
import { type SessionEffort } from '../../community/application/community-challenges.service';
import { CommunityService } from '../../community/application/community.service';
import { ProgramsRepository } from '../../programs/infrastructure/programs.repository';
import { ProgressService } from '../../progress/application/progress.service';
import { WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { type SessionWithSets, WorkoutsRepository } from '../infrastructure/workouts.repository';
import { ownedSession } from './workout-ownership';
import { presentSessionDetail, presentSessionSummary } from './workout.presenter';

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
   * Jour de programme honoré — facultatif, et jamais bloquant s'il est
   * inconnu : c'est ce qui coche une case du calendrier.
   */
  programDayId?: string;
  /**
   * Plan de la séance, copié du modèle par l'appareil au lancement. Absent
   * pour une séance libre. Transmis À LA CRÉATION et jamais ensuite : c'est
   * ce qui permet de reprendre la séance sur un autre appareil.
   */
  plan?: CreateSessionPlanItemInput[];
}

type PlanItemRow = Prisma.WorkoutSessionPlanItemUncheckedCreateInput;

/**
 * Ce qu'une séance a coûté en TEMPS et en DISTANCE, d'après ses séries.
 *
 * Fonction pure, et volontairement ailleurs que dans la durée de la séance :
 * `durationSeconds` mesure du début à la fin, pauses et rangement compris,
 * alors que ces secondes-ci sont celles qu'on a réellement chronométrées
 * série par série. Un défi qui compte des secondes d'effort ne doit pas
 * créditer le temps passé à discuter entre deux séries.
 *
 * Les séries sans chrono ni distance — la fonte, l'immense majorité —
 * apportent zéro, ce qui est exact.
 */
function sessionEffort(sets: SessionWithSets['sets']): SessionEffort {
  return sets.reduce(
    (total, set) => ({
      activeSeconds: total.activeSeconds + (set.durationSeconds ?? 0),
      distanceMeters: total.distanceMeters + (set.distanceMeters ?? 0),
    }),
    { activeSeconds: 0, distanceMeters: 0 },
  );
}

export interface SessionsPage {
  items: WorkoutSessionSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

/**
 * Séances offline-first : les identifiants viennent de l'appareil et chaque
 * écriture est REJOUABLE — renvoyer la même requête ne crée jamais de doublon.
 *
 * Ce service tient le CYCLE DE VIE d'une séance (ouverture, plan, clôture) ;
 * les séries qu'on y enregistre sont l'affaire de [WorkoutSetsService].
 */
@Injectable()
export class WorkoutsService {
  constructor(
    private readonly workouts: WorkoutsRepository,
    private readonly progress: ProgressService,
    private readonly community: CommunityService,
    private readonly templates: WorkoutTemplatesService,
    private readonly programs: ProgramsRepository,
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
        programDayId: await this.resolveProgramDay(userId, input.programDayId),
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
   * Le jour de programme, s'il existe ET appartient à cette personne.
   *
   * MÊME POLITIQUE QUE LE MODÈLE : inconnu, supprimé, ou venu du programme
   * d'autrui, il se perd en silence. Refuser rendrait un 4xx que la file de
   * synchronisation traite comme définitif, et la séance — le travail réel —
   * serait perdue pour une case de calendrier.
   */
  private async resolveProgramDay(
    userId: string,
    programDayId: string | undefined,
  ): Promise<string | null> {
    if (programDayId === undefined) {
      return null;
    }
    const day = await this.programs.findOwnedDay(programDayId, userId);
    return day === null ? null : day.id;
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
      await this.community.recordWorkoutCompleted(userId, endedAt, sessionEffort(closed.sets));
    }
    return presentSessionDetail(closed);
  }

  private ownedSession(userId: string, sessionId: string): Promise<SessionWithSets> {
    return ownedSession(this.workouts, userId, sessionId);
  }
}

import { type WorkoutSet as WorkoutSetContract } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { type WorkoutSession, type WorkoutSet, WorkoutSetKind } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { ProgressService } from '../../progress/application/progress.service';
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
  constructor(
    private readonly workouts: WorkoutsRepository,
    private readonly progress: ProgressService,
    @InjectPinoLogger(WorkoutSetsService.name)
    private readonly logger: PinoLogger,
  ) {}

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

    const { exerciseId, exerciseName } = await this.resolveExercise(input);

    const created = await this.workouts.createSet({
      id: input.id,
      sessionId: session.id,
      exerciseId,
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
    const avant = await ownedSet(this.workouts, userId, setId);
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
    await this.recomputeIfClosed(userId, avant);
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
    await this.recomputeIfClosed(userId, set);
  }

  /**
   * Remet les records d'accord avec l'historique quand on vient de toucher
   * une série d'une séance TERMINÉE.
   *
   * C'est le maillon qui manquait pour qu'une correction serve à quelque
   * chose. Les records ne s'écrivaient qu'à la clôture : corriger ensuite une
   * charge saisie 100 au lieu de 10, ou supprimer la série, laissait le
   * record faux — définitivement, puisqu'un maximum incrémental ne redescend
   * jamais. `PATCH /workout-sets/{id}` existait, était validé et testé, et ne
   * réparait rien.
   *
   * Rien à faire tant que la séance est en cours : aucun record n'a encore
   * été écrit pour elle, et recalculer à chaque série validée mettrait une
   * lecture d'historique sur le chemin le plus chaud de l'application.
   *
   * L'échec ne fait pas échouer la correction, pour la même raison qu'à la
   * clôture : la série corrigée est le fait, le record n'en est que la
   * lecture — et il se rattrape maintenant pour de bon.
   */
  private async recomputeIfClosed(
    userId: string,
    set: WorkoutSet & { session: WorkoutSession },
  ): Promise<void> {
    if (set.session.status !== 'COMPLETED') {
      return;
    }
    try {
      await this.progress.recomputeRecords(userId, [set.exerciseName]);
    } catch (error) {
      this.logger.error(
        { err: error, setId: set.id, exerciseName: set.exerciseName },
        'Échec du recalcul des records après correction — rattrapé à la prochaine écriture sur cet exercice',
      );
    }
  }

  /**
   * À quel exercice la série se rattache — identifiant ET nom, décidés
   * ENSEMBLE.
   *
   * Le nom du catalogue fait foi ; à défaut, celui transmis par l'appareil.
   * Sans l'un ni l'autre, la série n'a pas de sujet et la requête est refusée.
   *
   * POURQUOI L'IDENTIFIANT SUIT LE NOM. `exerciseId` part dans une colonne à
   * VRAIE clé étrangère (`Exercise?` avec `onDelete: SetNull`), et le DTO
   * n'exige qu'un UUID bien formé — jamais qu'il existe. L'ancienne version
   * ne choisissait que le nom et laissait passer l'identifiant tel quel : un
   * UUID inconnu — appareil resté hors ligne pendant qu'un exercice
   * disparaissait du catalogue, exactement le cas que l'offline-first
   * provoque — levait un P2003 que rien ne rattrapait, rendu en 500
   * `INTERNAL_ERROR`. La file de synchronisation, elle, ne rejoue jamais un
   * 5xx indéfiniment : la série finissait « épuisée ».
   *
   * Le module savait déjà faire, pour le PLAN de séance : « un `exerciseId`
   * inconnu ou dépublié dégrade la prévision en exercice LIBRE (clé étrangère
   * nulle, nom dénormalisé conservé) au lieu de faire échouer la requête :
   * une séance ne se perd jamais à cause du catalogue ». Une série vaut au
   * moins autant qu'une prévision — c'est le travail réellement fait.
   */
  private async resolveExercise(
    input: CreateSetInput,
  ): Promise<{ exerciseId: string | null; exerciseName: string }> {
    if (input.exerciseId !== undefined) {
      const name = await this.workouts.exercisePublishedName(input.exerciseId);
      if (name !== null) {
        return { exerciseId: input.exerciseId, exerciseName: name };
      }
    }
    const fallback = input.exerciseName?.trim();
    if (fallback === undefined || fallback.length === 0) {
      throw new BadRequestException('exerciseId inconnu et exerciseName absent.');
    }
    // Le catalogue ne reconnaît pas cet identifiant : la série devient LIBRE.
    return { exerciseId: null, exerciseName: fallback };
  }
}

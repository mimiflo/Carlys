import {
  type ExerciseProgression,
  type LifetimeStats,
  type PersonalRecord as PersonalRecordContract,
  type ProgressOverview,
  type ProgressPeriod,
} from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { type PersonalRecord, type WorkoutSet } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { ProgressRepository } from '../infrastructure/progress.repository';
import { computeBests } from './records.calculator';
import { computeRecordBreaks } from './record-breaks.calculator';
import { safeTimeZone } from '../../../common/utilities/time-zone';

const PERIOD_DAYS: Record<ProgressPeriod, number> = {
  week: 7,
  month: 30,
  year: 365,
};

function presentRecord(record: PersonalRecord): PersonalRecordContract {
  return {
    id: record.id,
    exerciseId: record.exerciseId,
    exerciseName: record.exerciseName,
    recordType: record.recordType,
    value: Number(record.value),
    reps: record.reps,
    weightKg: record.weightKg === null ? null : Number(record.weightKg),
    achievedAt: record.achievedAt.toISOString(),
  };
}

@Injectable()
export class ProgressService {
  constructor(
    private readonly progress: ProgressRepository,
    private readonly prisma: PrismaService,
    @InjectPinoLogger(ProgressService.name)
    private readonly logger: PinoLogger,
  ) {}

  /**
   * Recalcule les records après la clôture d'une séance. Ne fait JAMAIS
   * échouer la clôture : un échec est journalisé, et il se rattrape vraiment
   * — voir `recomputeRecords`, qui relit l'historique au lieu de mettre à
   * jour un maximum courant.
   */
  async updateRecordsForSession(
    userId: string,
    sessionId: string,
    sets: WorkoutSet[],
  ): Promise<void> {
    const exerciseNames = [
      ...new Set(sets.filter((set) => set.deletedAt === null).map((set) => set.exerciseName)),
    ];
    try {
      await this.recomputeRecords(userId, exerciseNames);
    } catch (error) {
      this.logger.error(
        { err: error, sessionId },
        'Échec du recalcul des records — rattrapé à la prochaine séance portant ces exercices',
      );
    }
  }

  /**
   * Rend les records de ces exercices ÉGAUX à ce que dit l'historique.
   *
   * POURQUOI CE N'EST PLUS UN MAXIMUM INCRÉMENTAL. L'ancienne version
   * comparait les séries de la séance qu'on venait de clore aux records
   * stockés et ne gardait que ce qui montait. Deux conséquences, et la
   * docstring en promettait la réparation sans la faire :
   *
   *  - un échec d'écriture perdait le record POUR TOUJOURS. La séance
   *    suivante ne voyait que ses propres séries : un 100 kg perdu laissait
   *    un 80 kg ultérieur devenir le record, puisque plus aucune ligne
   *    stockée ne s'y opposait. La promesse « rattrapés à la prochaine
   *    séance » était donc fausse, et elle masquait une perte de donnée ;
   *  - un record ne descendait JAMAIS. Corriger une charge saisie 100 au
   *    lieu de 10, ou supprimer la série, laissait le record intact.
   *
   * Recalculer depuis l'historique supprime les deux d'un coup : le record
   * cesse d'être un état à maintenir pour devenir une FONCTION des séries
   * stockées. Toute écriture qui change ces séries n'a plus qu'à rappeler
   * cette méthode pour les exercices touchés.
   */
  async recomputeRecords(userId: string, exerciseNames: string[]): Promise<void> {
    if (exerciseNames.length === 0) {
      return;
    }
    const sets = await this.progress.findSetsForRecords(userId, exerciseNames);
    const bests = computeBests(sets);
    const attendus = new Set(bests.map((best) => `${best.exerciseName}|${best.recordType}`));

    // Les records qui ne correspondent plus à aucune série : ce sont eux que
    // l'ancienne version laissait derrière elle.
    const existants = await this.progress.findRecords(userId, exerciseNames);
    await this.progress.deleteRecords(
      userId,
      existants
        .filter((record) => !attendus.has(`${record.exerciseName}|${record.recordType}`))
        .map((record) => ({
          exerciseName: record.exerciseName,
          recordType: record.recordType,
        })),
    );

    for (const best of bests) {
      await this.progress.upsertRecord(userId, best);
    }

    // Et les FRANCHISSEMENTS, dérivés du même historique : `PersonalRecord`
    // ne garde que le maximum courant, donc un 80 kg battu en mars par un
    // 85 en avril n'y laisse plus aucune trace. La frise, elle, raconte les
    // deux.
    await this.progress.syncRecordMilestones(
      userId,
      exerciseNames,
      computeRecordBreaks(sets).map((franchissement) => ({
        key: franchissement.key,
        occurredAt: franchissement.occurredAt,
        payload: {
          exerciseName: franchissement.exerciseName,
          recordType: franchissement.recordType,
          value: franchissement.value,
        },
      })),
    );
  }

  async overview(userId: string, period: ProgressPeriod): Promise<ProgressOverview> {
    const to = new Date();
    const from = new Date(to.getTime() - PERIOD_DAYS[period] * 24 * 3_600_000);

    // Les paniers se découpent dans le fuseau de la personne, pas en UTC :
    // sinon une séance du soir bascule dans la journée suivante et s'affiche
    // à la date de la veille. `safeTimeZone` couvre les lignes écrites avant
    // que le fuseau ne soit validé : mieux vaut un découpage UTC visible
    // qu'une erreur 500 sur une page de statistiques.
    const timeZone = safeTimeZone(await this.progress.userTimeZone(userId));

    const [totals, buckets] = await Promise.all([
      this.progress.periodTotals(userId, from, to),
      this.progress.volumeBuckets(userId, from, to, period, timeZone),
    ]);

    return {
      period,
      from: from.toISOString(),
      to: to.toISOString(),
      ...totals,
      points: buckets.map((bucket) => ({
        bucketStart: bucket.bucketStart.toISOString(),
        sessionsCount: bucket.sessionsCount,
        volumeKg: bucket.volumeKg,
      })),
    };
  }

  async records(userId: string): Promise<PersonalRecordContract[]> {
    return (await this.progress.listRecords(userId)).map(presentRecord);
  }

  /**
   * Ce que la vie entière compte, pour les récompenses.
   *
   * Le serveur sert les FAITS ; la RÈGLE reste côté mobile, dans le moteur
   * de récompenses qui en est le seul propriétaire. C'est pour ça que la
   * réponse porte les semaines brutes plutôt qu'une « meilleure série »
   * déjà calculée : la calculer ici en serait une seconde implémentation.
   */
  async lifetime(userId: string): Promise<LifetimeStats> {
    const timeZone = safeTimeZone(await this.progress.userTimeZone(userId));
    const weeks = await this.progress.lifetimeWeeks(userId, timeZone);
    return {
      completedSessions: weeks.reduce((total, week) => total + week.sessions, 0),
      weeks,
    };
  }

  async exerciseProgression(userId: string, exerciseId: string): Promise<ExerciseProgression> {
    const exercise = await this.prisma.exercise.findFirst({
      where: { id: exerciseId, isPublished: true },
      select: { id: true, name: true },
    });
    if (exercise === null) {
      throw new NotFoundException('Exercice introuvable.');
    }

    const [points, records] = await Promise.all([
      this.progress.exercisePoints(userId, exerciseId),
      this.progress.listRecords(userId, exercise.name),
    ]);

    return {
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      records: records.map(presentRecord),
      points: points.map((point) => ({
        sessionId: point.sessionId,
        date: point.date.toISOString(),
        maxWeightKg: point.maxWeightKg,
        maxReps: point.maxReps,
        volumeKg: point.volumeKg,
        distanceMeters: point.distanceMeters,
        durationSeconds: point.durationSeconds,
      })),
    };
  }
}

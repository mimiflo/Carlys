import {
  type BodyMetric as BodyMetricContract,
  type BodyMetricType,
  type ExerciseProgression,
  type PersonalRecord as PersonalRecordContract,
  type ProgressOverview,
  type ProgressPeriod,
} from '@carlys/api-contracts';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { type BodyMetric, type PersonalRecord, type WorkoutSet } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { ProgressRepository } from '../infrastructure/progress.repository';
import { computeSessionBests } from './records.calculator';

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

function presentBodyMetric(metric: BodyMetric): BodyMetricContract {
  return {
    id: metric.id,
    metricType: metric.metricType,
    value: Number(metric.value),
    measuredAt: metric.measuredAt.toISOString(),
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
   * échouer la clôture : un échec est journalisé, les records seront
   * rattrapés à la prochaine séance.
   */
  async updateRecordsForSession(
    userId: string,
    sessionId: string,
    sets: WorkoutSet[],
  ): Promise<void> {
    try {
      const candidates = computeSessionBests(sets);
      if (candidates.length === 0) {
        return;
      }
      const existing = await this.progress.findRecords(userId, [
        ...new Set(candidates.map((candidate) => candidate.exerciseName)),
      ]);
      const byKey = new Map(
        existing.map((record) => [`${record.exerciseName}|${record.recordType}`, record]),
      );

      for (const candidate of candidates) {
        const current = byKey.get(`${candidate.exerciseName}|${candidate.recordType}`);
        if (current === undefined || candidate.value > Number(current.value)) {
          await this.progress.upsertRecord(userId, candidate, sessionId);
        }
      }
    } catch (error) {
      this.logger.error(
        { err: error, sessionId },
        'Échec du recalcul des records — rattrapage à la prochaine séance',
      );
    }
  }

  async overview(userId: string, period: ProgressPeriod): Promise<ProgressOverview> {
    const to = new Date();
    const from = new Date(to.getTime() - PERIOD_DAYS[period] * 24 * 3_600_000);

    const [totals, buckets] = await Promise.all([
      this.progress.periodTotals(userId, from),
      this.progress.volumeBuckets(userId, from, period),
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
      })),
    };
  }

  // ── Mesures corporelles ─────────────────────────────────────────────────

  /** Création idempotente (id généré côté client). */
  async addBodyMetric(
    userId: string,
    input: { id: string; metricType: BodyMetricType; value: number; measuredAt: Date },
  ): Promise<BodyMetricContract> {
    const created = await this.progress.createBodyMetric({ userId, ...input });
    const stored = await this.progress.findBodyMetricById(input.id);
    if (stored === null || stored.userId !== userId) {
      if (!created && stored !== null) {
        throw new ConflictException('Identifiant de mesure déjà utilisé.');
      }
      throw new NotFoundException('Mesure introuvable.');
    }
    return presentBodyMetric(stored);
  }

  async listBodyMetrics(
    userId: string,
    metricType: BodyMetricType,
    limit: number,
  ): Promise<BodyMetricContract[]> {
    const metrics = await this.progress.listBodyMetrics(userId, metricType, limit);
    // Servies du plus ancien au plus récent (prêt pour les graphiques).
    return metrics.reverse().map(presentBodyMetric);
  }

  /** Idempotent : supprimer une mesure déjà supprimée ou inconnue aboutit. */
  async deleteBodyMetric(userId: string, id: string): Promise<void> {
    const metric = await this.progress.findBodyMetricById(id);
    if (metric === null) {
      return;
    }
    if (metric.userId !== userId) {
      throw new NotFoundException('Mesure introuvable.');
    }
    if (metric.deletedAt !== null) {
      return;
    }
    await this.progress.softDeleteBodyMetric(id);
  }
}

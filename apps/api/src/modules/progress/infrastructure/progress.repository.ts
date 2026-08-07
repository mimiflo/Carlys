import { type ProgressPeriod } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { type BodyMetric, type PersonalRecord, Prisma, WorkoutSessionStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type RecordCandidate } from '../application/records.calculator';

export interface PeriodTotals {
  sessionsCount: number;
  setsCount: number;
  totalVolumeKg: number;
  totalDurationSeconds: number;
}

export interface RawBucket {
  bucketStart: Date;
  sessionsCount: number;
  volumeKg: number;
}

export interface RawExercisePoint {
  sessionId: string;
  date: Date;
  maxWeightKg: number | null;
  maxReps: number | null;
  volumeKg: number;
}

/** Regroupement SQL par période — mots-clés STRICTEMENT whitelistés. */
const BUCKET_BY_PERIOD: Record<ProgressPeriod, string> = {
  week: 'day',
  month: 'week',
  year: 'month',
};

@Injectable()
export class ProgressRepository {
  constructor(private readonly prisma: PrismaService) {}

  async periodTotals(userId: string, from: Date): Promise<PeriodTotals> {
    const [sessions, setRows] = await Promise.all([
      this.prisma.workoutSession.aggregate({
        where: {
          userId,
          status: WorkoutSessionStatus.COMPLETED,
          deletedAt: null,
          startedAt: { gte: from },
        },
        _count: { id: true },
        _sum: { durationSeconds: true },
      }),
      this.prisma.$queryRaw<{ sets: bigint; volume: number | null }[]>(Prisma.sql`
        SELECT
          COUNT(s."id")                                     AS sets,
          COALESCE(SUM(s."reps" * s."weightKg"), 0)::float8 AS volume
        FROM "WorkoutSet" s
        JOIN "WorkoutSession" w ON w."id" = s."sessionId"
        WHERE w."userId" = ${userId}::uuid
          AND w."status" = 'COMPLETED'
          AND w."deletedAt" IS NULL
          AND w."startedAt" >= ${from}
          AND s."deletedAt" IS NULL
      `),
    ]);

    const setRow = setRows[0];
    return {
      sessionsCount: sessions._count.id,
      setsCount: Number(setRow?.sets ?? 0),
      totalVolumeKg: Math.round(Number(setRow?.volume ?? 0)),
      totalDurationSeconds: sessions._sum.durationSeconds ?? 0,
    };
  }

  async volumeBuckets(userId: string, from: Date, period: ProgressPeriod): Promise<RawBucket[]> {
    const bucket = Prisma.raw(`'${BUCKET_BY_PERIOD[period]}'`);
    const rows = await this.prisma.$queryRaw<
      { bucket_start: Date; sessions: bigint; volume: number | null }[]
    >(Prisma.sql`
      SELECT
        date_trunc(${bucket}, w."startedAt")              AS bucket_start,
        COUNT(DISTINCT w."id")                            AS sessions,
        COALESCE(SUM(s."reps" * s."weightKg"), 0)::float8 AS volume
      FROM "WorkoutSession" w
      LEFT JOIN "WorkoutSet" s
        ON s."sessionId" = w."id" AND s."deletedAt" IS NULL
      WHERE w."userId" = ${userId}::uuid
        AND w."status" = 'COMPLETED'
        AND w."deletedAt" IS NULL
        AND w."startedAt" >= ${from}
      GROUP BY bucket_start
      ORDER BY bucket_start ASC
    `);

    return rows.map((row) => ({
      bucketStart: row.bucket_start,
      sessionsCount: Number(row.sessions),
      volumeKg: Math.round(Number(row.volume ?? 0)),
    }));
  }

  async exercisePoints(userId: string, exerciseId: string): Promise<RawExercisePoint[]> {
    const rows = await this.prisma.$queryRaw<
      {
        session_id: string;
        date: Date;
        max_weight: number | null;
        max_reps: number | null;
        volume: number | null;
      }[]
    >(Prisma.sql`
      SELECT
        w."id"                                            AS session_id,
        w."startedAt"                                     AS date,
        MAX(s."weightKg")::float8                         AS max_weight,
        MAX(s."reps")                                     AS max_reps,
        COALESCE(SUM(s."reps" * s."weightKg"), 0)::float8 AS volume
      FROM "WorkoutSession" w
      JOIN "WorkoutSet" s ON s."sessionId" = w."id" AND s."deletedAt" IS NULL
      WHERE w."userId" = ${userId}::uuid
        AND w."status" = 'COMPLETED'
        AND w."deletedAt" IS NULL
        AND s."exerciseId" = ${exerciseId}::uuid
      GROUP BY w."id", w."startedAt"
      ORDER BY w."startedAt" ASC
      LIMIT 50
    `);

    return rows.map((row) => ({
      sessionId: row.session_id,
      date: row.date,
      maxWeightKg: row.max_weight === null ? null : Number(row.max_weight),
      maxReps: row.max_reps === null ? null : Number(row.max_reps),
      volumeKg: Math.round(Number(row.volume ?? 0)),
    }));
  }

  listRecords(userId: string, exerciseName?: string): Promise<PersonalRecord[]> {
    return this.prisma.personalRecord.findMany({
      where: { userId, ...(exerciseName === undefined ? {} : { exerciseName }) },
      orderBy: [{ achievedAt: 'desc' }, { exerciseName: 'asc' }],
    });
  }

  findRecords(userId: string, exerciseNames: string[]): Promise<PersonalRecord[]> {
    return this.prisma.personalRecord.findMany({
      where: { userId, exerciseName: { in: exerciseNames } },
    });
  }

  upsertRecord(userId: string, candidate: RecordCandidate, sessionId: string): Promise<void> {
    return this.prisma.personalRecord
      .upsert({
        where: {
          userId_exerciseName_recordType: {
            userId,
            exerciseName: candidate.exerciseName,
            recordType: candidate.recordType,
          },
        },
        create: {
          userId,
          exerciseId: candidate.exerciseId,
          exerciseName: candidate.exerciseName,
          recordType: candidate.recordType,
          value: candidate.value,
          reps: candidate.reps,
          weightKg: candidate.weightKg,
          achievedAt: candidate.achievedAt,
          sessionId,
        },
        update: {
          exerciseId: candidate.exerciseId,
          value: candidate.value,
          reps: candidate.reps,
          weightKg: candidate.weightKg,
          achievedAt: candidate.achievedAt,
          sessionId,
        },
      })
      .then(() => undefined);
  }

  // ── Mesures corporelles ─────────────────────────────────────────────────

  async createBodyMetric(data: {
    id: string;
    userId: string;
    metricType: BodyMetric['metricType'];
    value: number;
    measuredAt: Date;
  }): Promise<boolean> {
    try {
      await this.prisma.bodyMetric.create({ data });
      return true;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  findBodyMetricById(id: string): Promise<BodyMetric | null> {
    return this.prisma.bodyMetric.findUnique({ where: { id } });
  }

  listBodyMetrics(
    userId: string,
    metricType: BodyMetric['metricType'],
    limit: number,
  ): Promise<BodyMetric[]> {
    return this.prisma.bodyMetric.findMany({
      where: { userId, metricType, deletedAt: null },
      orderBy: { measuredAt: 'desc' },
      take: limit,
    });
  }

  softDeleteBodyMetric(id: string): Promise<void> {
    return this.prisma.bodyMetric
      .update({ where: { id }, data: { deletedAt: new Date() } })
      .then(() => undefined);
  }
}

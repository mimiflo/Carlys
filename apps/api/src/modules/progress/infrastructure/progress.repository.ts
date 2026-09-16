import { type ProgressPeriod } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import {
  type BodyMetric,
  type PersonalRecord,
  type PersonalRecordType,
  Prisma,
  type WorkoutSet,
  WorkoutSessionStatus,
} from '@prisma/client';
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

  /** Le fuseau déclaré par la personne, tel qu'il est en base. */
  async userTimeZone(userId: string): Promise<string | null> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { timezone: true },
    });
    return profile?.timezone ?? null;
  }

  /**
   * Totaux de la période — fenêtre fermée des DEUX côtés.
   *
   * La borne haute manquait, alors que le contrat en annonce une (`to` figure
   * dans la réponse). Les dates de séance viennent de l'horloge du téléphone,
   * jamais corrigées par le serveur : une séance datée du futur — horloge
   * déréglée, ou saisie aberrante — passait la borne basse de TOUTES les
   * périodes, et pour toujours. Le `lte` est la vraie correction ; la borne
   * de validation qui l'accompagne (`nowWithClockSkew`) n'arrête que
   * l'absurde, exprès, pour ne pas rejeter une séance légitime dont l'horloge
   * avance de trois minutes.
   */
  async periodTotals(userId: string, from: Date, to: Date): Promise<PeriodTotals> {
    const [sessions, setRows] = await Promise.all([
      this.prisma.workoutSession.aggregate({
        where: {
          userId,
          status: WorkoutSessionStatus.COMPLETED,
          deletedAt: null,
          startedAt: { gte: from, lte: to },
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
          AND w."startedAt" <= ${to}
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

  /**
   * Volume par jour ou par semaine, découpé DANS LE FUSEAU DE LA PERSONNE.
   *
   * `startedAt` est un instant UTC ; `date_trunc` seul découpe donc des
   * journées UTC. Pour quelqu'un à Montréal (UTC−4 en septembre), une séance
   * de 21 h locales vaut 01 h UTC le lendemain : deux séances du même soir
   * tombaient dans deux paniers différents, et l'un d'eux s'affichait à la
   * date de la veille une fois ramené à l'heure locale. Le dépôt en fait
   * pourtant une règle : le serveur ne découpe jamais les journées à la place
   * du client.
   *
   * Le double `AT TIME ZONE` est l'idiome PostgreSQL : le premier ramène
   * l'instant à l'heure murale locale, le second renvoie le minuit local
   * obtenu vers l'instant qui lui correspond. Le contrat est inchangé —
   * `bucketStart` reste un instant — mais il tombe désormais sur un vrai
   * minuit local.
   */
  async volumeBuckets(
    userId: string,
    from: Date,
    to: Date,
    period: ProgressPeriod,
    timeZone: string,
  ): Promise<RawBucket[]> {
    const bucket = Prisma.raw(`'${BUCKET_BY_PERIOD[period]}'`);
    const rows = await this.prisma.$queryRaw<
      { bucket_start: Date; sessions: bigint; volume: number | null }[]
    >(Prisma.sql`
      SELECT
        date_trunc(${bucket}, w."startedAt" AT TIME ZONE ${timeZone})
          AT TIME ZONE ${timeZone}                        AS bucket_start,
        COUNT(DISTINCT w."id")                            AS sessions,
        COALESCE(SUM(s."reps" * s."weightKg"), 0)::float8 AS volume
      FROM "WorkoutSession" w
      LEFT JOIN "WorkoutSet" s
        ON s."sessionId" = w."id" AND s."deletedAt" IS NULL
      WHERE w."userId" = ${userId}::uuid
        AND w."status" = 'COMPLETED'
        AND w."deletedAt" IS NULL
        AND w."startedAt" >= ${from}
        AND w."startedAt" <= ${to}
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

  /**
   * TOUTES les séries qui comptent pour ces exercices, tous entraînements
   * confondus — la matière d'un recalcul de record.
   *
   * Les trois filtres sont la définition même de « ce qui compte », et ils
   * sont déjà ceux de `exercisePoints` juste au-dessus : séance terminée,
   * séance non supprimée, série non supprimée. Une séance ABANDONNÉE n'entre
   * donc pas, ce qu'un test e2e exige explicitement.
   *
   * Pas d'index dédié, et c'est délibéré : le plan part de
   * `WorkoutSession(userId, startedAt)`, qui existe, puis rejoint les séries
   * par `WorkoutSet(sessionId, position)`, qui existe aussi. La lecture est
   * donc bornée à l'historique de LA personne, jamais à la table entière, et
   * elle n'a lieu qu'à la clôture d'une séance ou à la correction d'une
   * série. Indexer `exerciseName` coûterait une écriture de plus sur la
   * table la plus écrite du schéma pour un gain que rien ne mesure encore.
   */
  findSetsForRecords(userId: string, exerciseNames: string[]): Promise<WorkoutSet[]> {
    return this.prisma.workoutSet.findMany({
      where: {
        exerciseName: { in: exerciseNames },
        deletedAt: null,
        session: { userId, status: 'COMPLETED', deletedAt: null },
      },
    });
  }

  /**
   * Retire les records devenus sans objet — la série qui les portait a été
   * corrigée vers le bas ou supprimée, et plus aucune ne les justifie.
   *
   * Sans cette suppression, un record survivrait au fait qui l'a produit :
   * c'est précisément ce qui rendait une charge mal saisie définitive.
   */
  async deleteRecords(
    userId: string,
    keys: { exerciseName: string; recordType: PersonalRecordType }[],
  ): Promise<void> {
    if (keys.length === 0) {
      return;
    }
    await this.prisma.personalRecord.deleteMany({
      where: { userId, OR: keys },
    });
  }

  upsertRecord(userId: string, candidate: RecordCandidate): Promise<void> {
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
          sessionId: candidate.sessionId,
        },
        update: {
          exerciseId: candidate.exerciseId,
          value: candidate.value,
          reps: candidate.reps,
          weightKg: candidate.weightKg,
          achievedAt: candidate.achievedAt,
          sessionId: candidate.sessionId,
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

  /**
   * Corrige une mesure en place. `data` ne porte que ce qui change : Prisma
   * laisse intactes les colonnes absentes, et `updatedAt` se met à jour tout
   * seul (`@updatedAt`), ce qui garde une trace de la correction.
   */
  updateBodyMetric(id: string, data: { value?: number; measuredAt?: Date }): Promise<BodyMetric> {
    return this.prisma.bodyMetric.update({ where: { id }, data });
  }

  softDeleteBodyMetric(id: string): Promise<void> {
    return this.prisma.bodyMetric
      .update({ where: { id }, data: { deletedAt: new Date() } })
      .then(() => undefined);
  }
}

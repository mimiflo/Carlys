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
  /**
   * Ce que la séance a parcouru et chronométré sur CET exercice.
   *
   * Sommés, jamais maximisés : trois fractionnés de 400 m font 1 200 m de
   * course, alors que la charge d'une série ne s'additionne pas d'une série
   * à l'autre. Zéro sur un exercice de fonte, ce qui est exact — la même
   * règle que `sessionEffort` côté séances.
   */
  distanceMeters: number;
  durationSeconds: number;
}

/**
 * Une semaine de la vie entière : le LUNDI qui l'ouvre, et le nombre de
 * séances terminées cette semaine-là.
 *
 * Des FAITS, pas une règle : c'est le moteur de récompenses côté mobile qui
 * décide ce qu'est une « meilleure série » ou une « semaine équilibrée », et
 * il reste le seul à le décider. Recalculer ces règles en SQL les
 * dupliquerait, et deux copies divergent.
 */
export interface RawLifetimeWeek {
  /** Lundi de la semaine, `YYYY-MM-DD` dans le fuseau de la personne. */
  mondayOn: string;
  sessions: number;
}

/** Une ligne brute de la frise, avant mise en forme. */
export interface RawTimelineEvent {
  kind: string;
  id: string;
  occurredAt: Date;
  payload: Prisma.JsonValue;
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

  /**
   * Les semaines de la VIE ENTIÈRE où au moins une séance a été terminée.
   *
   * Sans bornes de date et sans `LIMIT` : c'est tout le propos. Le mobile
   * dérivait ces compteurs de son historique LOCAL, plafonné à 60 séances
   * par `WorkoutSessionDownloader.restoredSessionsMax` — un téléphone neuf
   * sur un compte à 200 séances en voyait 60, ne re-méritait pas
   * `discipline-150`, et la récompense DISPARAISSAIT, ce que le journal
   * promet justement de ne jamais faire.
   *
   * Le volume reste minuscule : une ligne par semaine ACTIVE, soit ~104
   * lignes sur deux ans, ~520 sur dix ans.
   *
   * Découpage dans le fuseau de la personne, comme `volumeBuckets` et pour
   * la même raison : une séance du dimanche soir bascule au lundi en UTC, et
   * changerait donc de semaine. `date_trunc('week', …)` rend le LUNDI, qui
   * est aussi le jour d'ouverture retenu côté mobile.
   */
  async lifetimeWeeks(userId: string, timeZone: string): Promise<RawLifetimeWeek[]> {
    const rows = await this.prisma.$queryRaw<{ monday: Date; sessions: bigint }[]>(Prisma.sql`
      SELECT
        date_trunc('week', w."startedAt" AT TIME ZONE ${timeZone}) AS monday,
        COUNT(*)                                                   AS sessions
      FROM "WorkoutSession" w
      WHERE w."userId" = ${userId}::uuid
        AND w."status" = 'COMPLETED'
        AND w."deletedAt" IS NULL
      GROUP BY monday
      ORDER BY monday ASC
    `);

    return rows.map((row) => ({
      // `date_trunc` sans `AT TIME ZONE` de retour rend un timestamp SANS
      // fuseau, que le pilote présente en UTC : ses composantes UTC sont
      // donc exactement le minuit local cherché.
      mondayOn: row.monday.toISOString().slice(0, 10),
      sessions: Number(row.sessions),
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
        distance: number | null;
        duration: number | null;
      }[]
    >(Prisma.sql`
      SELECT
        w."id"                                            AS session_id,
        w."startedAt"                                     AS date,
        MAX(s."weightKg")::float8                         AS max_weight,
        MAX(s."reps")                                     AS max_reps,
        COALESCE(SUM(s."reps" * s."weightKg"), 0)::float8 AS volume,
        COALESCE(SUM(s."distanceMeters"), 0)::float8      AS distance,
        COALESCE(SUM(s."durationSeconds"), 0)::float8     AS duration
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
      distanceMeters: Math.round(Number(row.distance ?? 0)),
      durationSeconds: Math.round(Number(row.duration ?? 0)),
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
  /**
   * LA FRISE : quatre sources fusionnées, une page, un curseur.
   *
   * Séances, mesures et leçons sont DÉRIVÉES — ce sont déjà trois tables
   * datées et indexées, et les recopier dans une table d'événements
   * ajouterait un état à maintenir pour zéro gain. Les franchissements, eux,
   * sont lus dans `ProgressMilestone` : ils ne correspondent à aucune ligne
   * existante.
   *
   * LE CURSEUR ENCODE LE COUPLE `(occurredAt, id)`, jamais l'id seul. Les
   * autres listes du dépôt s'en tirent avec l'id parce qu'une seule table
   * est triée ; un flux fusionné a des ex æquo à la milliseconde près, et un
   * curseur sur l'id seul sauterait des lignes ou les rejouerait.
   *
   * Les leçons sont GROUPÉES PAR JOUR après dédoublonnage par leçon. Sans le
   * `DISTINCT ON`, la même leçon répondue deux jours ferait deux lignes — le
   * serveur garde les deux réponses (la clé est `(userId, lessonId,
   * answeredOn)`) là où l'appareil applique « la première gagne ». Sans le
   * groupement, cinquante-huit lignes de bruit noieraient la frise.
   */
  async timeline(
    userId: string,
    limit: number,
    kinds: string[],
    cursor: { occurredAt: Date; id: string } | null,
  ): Promise<RawTimelineEvent[]> {
    const voulu = (kind: string) => kinds.length === 0 || kinds.includes(kind);
    const borne =
      cursor === null
        ? Prisma.sql`TRUE`
        : Prisma.sql`(e.occurred_at, e.id) < (${cursor.occurredAt}, ${cursor.id})`;

    const sources: Prisma.Sql[] = [];
    if (voulu('SESSION')) {
      sources.push(Prisma.sql`
        SELECT 'SESSION' AS kind, w."id"::text AS id, w."startedAt" AS occurred_at,
               jsonb_build_object(
                 'name', w."name",
                 'setsCount', (SELECT COUNT(*) FROM "WorkoutSet" s
                                WHERE s."sessionId" = w."id" AND s."deletedAt" IS NULL),
                 'volumeKg', COALESCE((SELECT SUM(s."reps" * s."weightKg") FROM "WorkoutSet" s
                                        WHERE s."sessionId" = w."id" AND s."deletedAt" IS NULL), 0)
               ) AS payload
        FROM "WorkoutSession" w
        WHERE w."userId" = ${userId}::uuid
          AND w."status" = 'COMPLETED'
          AND w."deletedAt" IS NULL
      `);
    }
    if (voulu('MEASURE')) {
      sources.push(Prisma.sql`
        SELECT 'MEASURE' AS kind, m."id"::text AS id, m."measuredAt" AS occurred_at,
               jsonb_build_object('metricType', m."metricType", 'value', m."value") AS payload
        FROM "BodyMetric" m
        WHERE m."userId" = ${userId}::uuid AND m."deletedAt" IS NULL
      `);
    }
    if (voulu('LESSON')) {
      sources.push(Prisma.sql`
        SELECT 'LESSON' AS kind, 'lesson-' || d.jour AS id,
               (d.jour || ' 12:00:00')::timestamp AS occurred_at,
               jsonb_build_object('lessons', COUNT(*)) AS payload
        FROM (
          SELECT DISTINCT ON (q."lessonId") q."lessonId", q."answeredOn" AS jour
          FROM "QuizAnswer" q
          WHERE q."userId" = ${userId}::uuid
          ORDER BY q."lessonId", q."createdAt" ASC
        ) d
        GROUP BY d.jour
      `);
    }
    const franchissements = ['RECORD', 'REWARD', 'TITLE'].filter(voulu);
    if (franchissements.length > 0) {
      sources.push(Prisma.sql`
        SELECT ms."kind"::text AS kind, ms."id"::text AS id, ms."occurredAt" AS occurred_at,
               -- La CLÉ voyage avec la ligne : sans elle, « Récompense
               -- obtenue » ne nomme rien, et le client n'a aucun moyen de
               -- retrouver de laquelle il s'agit dans son catalogue.
               jsonb_build_object('key', ms."key") ||
                 COALESCE(ms."payload", '{}'::jsonb) AS payload
        FROM "ProgressMilestone" ms
        WHERE ms."userId" = ${userId}::uuid
          AND ms."kind"::text IN (${Prisma.join(franchissements)})
      `);
    }
    if (sources.length === 0) {
      return [];
    }

    const rows = await this.prisma.$queryRaw<
      { kind: string; id: string; occurred_at: Date; payload: Prisma.JsonValue }[]
    >(Prisma.sql`
      SELECT e.kind, e.id, e.occurred_at, e.payload
      FROM (${Prisma.join(sources, ' UNION ALL ')}) AS e
      WHERE ${borne}
      ORDER BY e.occurred_at DESC, e.id DESC
      LIMIT ${limit}
    `);

    return rows.map((row) => ({
      kind: row.kind,
      id: row.id,
      occurredAt: row.occurred_at,
      payload: row.payload,
    }));
  }

  /**
   * Importe des franchissements décidés par le MOBILE, « la plus ANCIENNE
   * date gagne ».
   *
   * Le journal local date une récompense du jour où l'application a
   * REGARDÉ, pas du jour où le cap a été franchi — il le dit lui-même. Deux
   * appareils n'ont donc pas regardé le même jour, et sans cette règle le
   * dernier à parler réécrirait l'histoire. `LEAST` la tranche en SQL, dans
   * l'écriture elle-même : deux imports simultanés ne peuvent pas la
   * contourner.
   *
   * Symétrique de `pullAnswers` côté Academy : le serveur COMBLE les trous,
   * il ne réécrit jamais.
   */
  async importMilestones(
    userId: string,
    milestones: ReadonlyArray<{ kind: 'REWARD' | 'TITLE'; key: string; occurredAt: Date }>,
  ): Promise<void> {
    if (milestones.length === 0) {
      return;
    }
    const valeurs = milestones.map(
      (entry) =>
        Prisma.sql`(gen_random_uuid(), ${userId}::uuid, ${entry.kind}::"MilestoneKind", ${entry.key}, ${entry.occurredAt})`,
    );
    await this.prisma.$executeRaw(Prisma.sql`
      INSERT INTO "ProgressMilestone" ("id", "userId", "kind", "key", "occurredAt")
      VALUES ${Prisma.join(valeurs)}
      ON CONFLICT ("userId", "kind", "key")
      DO UPDATE SET "occurredAt" = LEAST(
        "ProgressMilestone"."occurredAt",
        EXCLUDED."occurredAt"
      )
    `);
  }

  /**
   * Met les franchissements de RECORD de ces exercices à l'ÉGAL de ce que
   * dit l'historique : on écrit ce qui manque, on retire ce qui n'a plus de
   * série pour le justifier.
   *
   * Même philosophie que `recomputeRecords` juste à côté — un franchissement
   * est une FONCTION des séries stockées, pas un état à maintenir. Sans la
   * suppression, une charge saisie 100 au lieu de 10 laisserait derrière
   * elle un record qui n'a jamais eu lieu, sur une frise qui prétend
   * raconter une histoire vraie.
   */
  async syncRecordMilestones(
    userId: string,
    exerciseNames: string[],
    breaks: ReadonlyArray<{ key: string; occurredAt: Date; payload: Prisma.InputJsonValue }>,
  ): Promise<void> {
    if (exerciseNames.length === 0) {
      return;
    }
    const gardees = breaks.map((entry) => entry.key);
    await this.prisma.progressMilestone.deleteMany({
      where: {
        userId,
        kind: 'RECORD',
        key: { notIn: gardees.length === 0 ? [''] : gardees },
        // Bornée aux exercices recalculés : les autres n'ont pas bougé, et
        // les relire pour les réécrire à l'identique coûterait tout
        // l'historique à chaque clôture de séance.
        OR: exerciseNames.map((name) => ({ key: { startsWith: `record:${name}|` } })),
      },
    });
    if (breaks.length === 0) {
      return;
    }
    await this.prisma.progressMilestone.createMany({
      data: breaks.map((entry) => ({
        userId,
        kind: 'RECORD' as const,
        key: entry.key,
        occurredAt: entry.occurredAt,
        payload: entry.payload,
      })),
      // « La première gagne, rien ne s'efface » : rejouer n'écrase pas une
      // date déjà inscrite.
      skipDuplicates: true,
    });
  }

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

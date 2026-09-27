import { Prisma } from '@prisma/client';

/**
 * LE SQL DE LA FRISE — voir `ProgressRepository.timeline` pour ce qu'elle
 * raconte et pourquoi le curseur est un couple.
 *
 * Rangé à part parce qu'il est long et qu'il a une forme à respecter : chaque
 * source rend les CINQ mêmes colonnes (`kind`, `id`, `occurred_at`,
 * `payload`, `session_id`), sans quoi l'`UNION ALL` refuse de les empiler.
 */

/**
 * Les sources de la frise voulues par `kinds` (toutes s'il est vide).
 *
 * Une séance ne porte ici que son NOM : son volume et son nombre de séries
 * se calculent APRÈS la coupe de la page (voir [timelinePage]). `session_id`
 * est là pour ça ; nul pour toutes les autres sources.
 */
export function timelineSources(userId: string, kinds: readonly string[]): Prisma.Sql[] {
  const voulu = (kind: string) => kinds.length === 0 || kinds.includes(kind);
  const sources: Prisma.Sql[] = [];
  if (voulu('SESSION')) {
    sources.push(Prisma.sql`
      SELECT 'SESSION' AS kind, w."id"::text AS id, w."startedAt" AS occurred_at,
             jsonb_build_object('name', w."name") AS payload,
             w."id" AS session_id
      FROM "WorkoutSession" w
      WHERE w."userId" = ${userId}::uuid
        AND w."status" = 'COMPLETED'
        AND w."deletedAt" IS NULL
    `);
  }
  if (voulu('MEASURE')) {
    sources.push(Prisma.sql`
      SELECT 'MEASURE' AS kind, m."id"::text AS id, m."measuredAt" AS occurred_at,
             jsonb_build_object('metricType', m."metricType", 'value', m."value") AS payload,
             NULL::uuid AS session_id
      FROM "BodyMetric" m
      WHERE m."userId" = ${userId}::uuid AND m."deletedAt" IS NULL
    `);
  }
  if (voulu('LESSON')) {
    sources.push(Prisma.sql`
      SELECT 'LESSON' AS kind, 'lesson-' || d.jour AS id,
             (d.jour || ' 12:00:00')::timestamp AS occurred_at,
             jsonb_build_object('lessons', COUNT(*)) AS payload,
             NULL::uuid AS session_id
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
               COALESCE(ms."payload", '{}'::jsonb) AS payload,
             NULL::uuid AS session_id
      FROM "ProgressMilestone" ms
      WHERE ms."userId" = ${userId}::uuid
        AND ms."kind"::text IN (${Prisma.join(franchissements)})
    `);
  }
  return sources;
}

/**
 * Une page de la frise : fusion, curseur, tri, coupe — PUIS le volume et le
 * nombre de séries des seules séances de la page.
 *
 * Ces deux agrégats vivaient dans la source des séances, sous l'`UNION ALL` :
 * PostgreSQL les calculait donc pour TOUTES les séances du compte avant de
 * trier et de n'en garder que trente. Mesuré sur un historique de 496
 * séances : deux sous-requêtes exécutées 496 fois chacune, 17 ms sur 21,6,
 * à chaque page, et un coût qui grandissait avec l'historique. Calculés
 * après la coupe, ils ne portent plus que sur la page.
 */
export function timelinePage(
  sources: readonly Prisma.Sql[],
  cursor: { occurredAt: Date; id: string } | null,
  limit: number,
): Prisma.Sql {
  const borne =
    cursor === null
      ? Prisma.sql`TRUE`
      : Prisma.sql`(e.occurred_at, e.id) < (${cursor.occurredAt}, ${cursor.id})`;
  return Prisma.sql`
    SELECT p.kind, p.id, p.occurred_at,
           CASE WHEN p.session_id IS NULL THEN p.payload
                ELSE p.payload || jsonb_build_object(
                       'setsCount', agg.sets_count,
                       'volumeKg', agg.volume_kg)
           END AS payload
    FROM (
      SELECT e.kind, e.id, e.occurred_at, e.payload, e.session_id
      FROM (${Prisma.join([...sources], ' UNION ALL ')}) AS e
      WHERE ${borne}
      ORDER BY e.occurred_at DESC, e.id DESC
      LIMIT ${limit}
    ) AS p
    LEFT JOIN LATERAL (
      SELECT COUNT(*) AS sets_count,
             COALESCE(SUM(s."reps" * s."weightKg"), 0) AS volume_kg
      FROM "WorkoutSet" s
      WHERE s."sessionId" = p.session_id AND s."deletedAt" IS NULL
    ) AS agg ON p.session_id IS NOT NULL
    ORDER BY p.occurred_at DESC, p.id DESC
  `;
}

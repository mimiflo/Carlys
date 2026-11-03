-- Mensurations : sept tours, en centimètres, dans la même table que le poids
-- (`BodyMetric`), donc sept valeurs de plus pour `BodyMetricType`.
--
-- `ALTER TYPE … ADD VALUE` passe dans une transaction depuis PostgreSQL 12
-- (la production tourne en 17) : la seule contrainte est qu'une valeur
-- ajoutée ne s'UTILISE pas avant le COMMIT. Cette migration ne fait
-- qu'ajouter, aucune ligne ne s'en sert ici : elle reste d'un seul tenant.
-- Vérifié en rejouant ces sept lignes entre BEGIN et COMMIT, puis par
-- `prisma migrate deploy`.
ALTER TYPE "BodyMetricType" ADD VALUE 'WAIST_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'HIPS_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'CHEST_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'ARM_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'THIGH_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'CALF_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'NECK_CM';

-- Mensurations : sept tours, en centimètres, dans la même table que le poids
-- (`BodyMetric`), donc sept valeurs de plus pour `BodyMetricType`.
--
-- `ALTER TYPE … ADD VALUE` passe dans une transaction depuis PostgreSQL 12
-- (la production tourne en 17) : la seule contrainte est qu'une valeur
-- ajoutée ne s'UTILISE pas avant le COMMIT. Cette migration ne fait
-- qu'ajouter, aucune ligne ne s'en sert ici : elle reste d'un seul tenant.
-- Vérifié en rejouant ces sept lignes entre BEGIN et COMMIT, puis par
-- `prisma migrate deploy`.
--
-- IRRÉVERSIBLE : PostgreSQL n'a pas de `ALTER TYPE … DROP VALUE`. Le retour
-- arrière se fait par l'IMAGE seule ; les sept valeurs restent dans le type,
-- et les lignes `*_CM` déjà saisies restent dans la table. Tant que
-- l'ancienne image tourne sur cette base, son client Prisma ne connaît pas
-- ces valeurs : lire une telle ligne lève « Value 'WAIST_CM' not found in
-- enum 'BodyMetricType' » (vérifié avec le client généré du schéma
-- d'avant), donc `PATCH` et `DELETE /body-metrics/:id` d'une mensuration
-- répondent 500. `GET /body-metrics` (filtré sur le poids par défaut) et la
-- frise (SQL brut) continuent de répondre.
--
-- Ordre de déploiement : l'API d'abord (migration puis image), l'appli
-- ensuite — une appli qui saisit des mensurations face à l'ancienne API
-- recevrait un 400 sur le type.
ALTER TYPE "BodyMetricType" ADD VALUE 'WAIST_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'HIPS_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'CHEST_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'ARM_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'THIGH_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'CALF_CM';
ALTER TYPE "BodyMetricType" ADD VALUE 'NECK_CM';

-- La table des membres est TENUE le temps de la migration : l'ancienne API
-- sert encore pendant `migrate deploy`, et une place prise entre le
-- remplissage ci-dessous et la pose du déclencheur ne serait comptée nulle
-- part — le compteur resterait trop bas pour toujours. SHARE ROW EXCLUSIVE
-- laisse lire (classements, scores) et retient les écritures, le temps d'un
-- `GROUP BY` ; 5 s au plus pour l'obtenir, sinon la migration échoue et le
-- déploiement s'arrête sans rien basculer (à relancer hors du lundi).
SET LOCAL lock_timeout = '5s';
LOCK TABLE "LeagueMembership" IN SHARE ROW EXCLUSIVE MODE;

-- CreateTable
CREATE TABLE "LeagueCohort" (
    "periodKey" TEXT NOT NULL,
    "division" "LeagueDivision" NOT NULL,
    "cohort" INTEGER NOT NULL,
    "members" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "LeagueCohort_pkey" PRIMARY KEY ("periodKey","division","cohort")
);

-- L'effectif de chaque groupe déjà ouvert : repris tel qu'il est.
INSERT INTO "LeagueCohort" ("periodKey", "division", "cohort", "members")
SELECT "periodKey", "division", "cohort", COUNT(*)::INTEGER
FROM "LeagueMembership"
GROUP BY "periodKey", "division", "cohort";

-- Tenu par la BASE, à chaque ligne de LeagueMembership écrite, déplacée ou
-- supprimée : aucun chemin d'écriture — code, règlement, suppression de
-- compte en cascade — ne peut le faire dériver. Un UPDATE qui ne touche ni
-- la période, ni la division, ni le groupe (score, rang, règlement) ne le
-- déclenche pas. Le placement le lit SOUS le verrou consultatif de
-- (période, division), qui reste ce qui empêche de remplir un groupe à 21.
CREATE FUNCTION "league_cohort_count"() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    UPDATE "LeagueCohort" SET "members" = "members" - 1
    WHERE "periodKey" = OLD."periodKey"
      AND "division" = OLD."division"
      AND "cohort" = OLD."cohort";
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    INSERT INTO "LeagueCohort" ("periodKey", "division", "cohort", "members")
    VALUES (NEW."periodKey", NEW."division", NEW."cohort", 1)
    ON CONFLICT ("periodKey", "division", "cohort")
    DO UPDATE SET "members" = "LeagueCohort"."members" + 1;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER "league_cohort_count"
AFTER INSERT OR DELETE OR UPDATE OF "periodKey", "division", "cohort"
ON "LeagueMembership"
FOR EACH ROW EXECUTE FUNCTION "league_cohort_count"();

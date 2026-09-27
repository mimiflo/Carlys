-- La révision d'une séance (`WorkoutSession.revision`) monte EN BASE, par
-- déclencheurs, à chaque écriture de la séance, de l'une de ses séries ou de
-- son plan.
--
-- C'était le code de l'API qui l'incrémentait. Or le retour arrière du
-- déploiement remet le CODE d'avant sans défaire le SCHÉMA : ce code écrit
-- sans connaître la révision, un téléphone qui l'avait déjà lue sautait la
-- séance pour de bon, et les corrections faites ailleurs ne lui arrivaient
-- jamais. En base, aucune écriture ne l'oublie, quel que soit le code qui
-- la fait, celui d'hier comme celui de demain.
--
-- Rien d'autre ne change : ni colonne, ni donnée. Le code précédent reste
-- compatible avec ce schéma.

-- La séance : toute mise à jour la fait monter d'un cran, et d'un seul,
-- y compris celle qui vient des déclencheurs ci-dessous.
CREATE FUNCTION "workout_session_revise"() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW."revision" := OLD."revision" + 1;
  RETURN NEW;
END;
$$;

CREATE TRIGGER "WorkoutSession_revision"
  BEFORE UPDATE ON "WorkoutSession"
  FOR EACH ROW EXECUTE FUNCTION "workout_session_revise"();

-- Une série ou une prévision créée ou modifiée (correction, suppression
-- douce, appariement, prévision passée) : sa séance monte d'un cran. UNE
-- mise à jour par séance touchée et par instruction, pas une par ligne : le
-- plan d'une séance (jusqu'à 600 prévisions) s'écrit en une instruction, qui
-- réécrirait sinon la séance 600 fois (mesuré : 5 à 9 ms sans déclencheur,
-- 17 à 28 ms ligne par ligne). Une instruction qui ne touche aucune ligne
-- (rejeu) laisse la table de transition vide : rien ne monte.
CREATE FUNCTION "workout_session_revise_touched"() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE "WorkoutSession" SET "revision" = "revision" + 1
  WHERE "id" IN (SELECT "sessionId" FROM "touchees");
  RETURN NULL;
END;
$$;

-- Une table de transition n'accepte qu'un événement par déclencheur : d'où
-- deux déclencheurs par table.
CREATE TRIGGER "WorkoutSet_revision_insert"
  AFTER INSERT ON "WorkoutSet" REFERENCING NEW TABLE AS "touchees"
  FOR EACH STATEMENT EXECUTE FUNCTION "workout_session_revise_touched"();

CREATE TRIGGER "WorkoutSet_revision_update"
  AFTER UPDATE ON "WorkoutSet" REFERENCING NEW TABLE AS "touchees"
  FOR EACH STATEMENT EXECUTE FUNCTION "workout_session_revise_touched"();

CREATE TRIGGER "WorkoutSessionPlanItem_revision_insert"
  AFTER INSERT ON "WorkoutSessionPlanItem" REFERENCING NEW TABLE AS "touchees"
  FOR EACH STATEMENT EXECUTE FUNCTION "workout_session_revise_touched"();

CREATE TRIGGER "WorkoutSessionPlanItem_revision_update"
  AFTER UPDATE ON "WorkoutSessionPlanItem" REFERENCING NEW TABLE AS "touchees"
  FOR EACH STATEMENT EXECUTE FUNCTION "workout_session_revise_touched"();

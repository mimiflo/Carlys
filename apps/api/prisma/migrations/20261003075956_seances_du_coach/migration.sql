-- AlterTable
ALTER TABLE "WorkoutTemplate" ADD COLUMN     "fromCoach" BOOLEAN NOT NULL DEFAULT false;

-- Les séances déjà enregistrées par le coach (« Ok crée-la ») : leur modèle
-- porte l'identifiant de la proposition dont il vient.
UPDATE "WorkoutTemplate" t SET "fromCoach" = true
WHERE EXISTS (SELECT 1 FROM "CoachSessionProposal" p WHERE p.id = t.id);

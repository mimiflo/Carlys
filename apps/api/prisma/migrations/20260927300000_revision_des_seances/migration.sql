-- Révision d'une séance, servie au rapatriement mobile (voir
-- `WorkoutSession.revision` dans schema.prisma). Colonne NON NULL à valeur
-- par défaut constante : PostgreSQL l'ajoute sans réécrire la table.
ALTER TABLE "WorkoutSession" ADD COLUMN "revision" INTEGER NOT NULL DEFAULT 1;

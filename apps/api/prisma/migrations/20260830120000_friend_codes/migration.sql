-- Code ami : identité partageable de chaque compte (8 caractères d'un
-- alphabet sans ambiguïté visuelle), affichée en XXXX-XXXX et portée par
-- le QR de profil. Migration écrite à la main : la colonne arrive NOT NULL
-- sur une table déjà peuplée, il faut donc remplir avant de contraindre.

ALTER TABLE "User" ADD COLUMN "friendCode" TEXT;

-- Remplissage des comptes existants : code dérivé de l'identifiant (md5),
-- projeté caractère par caractère sur l'alphabet officiel — déterministe,
-- sans extension, et corrélé par ligne. Le sel 'friend-code' évite que le
-- code soit un simple digest de l'id, que quiconque pourrait recalculer.
UPDATE "User"
SET "friendCode" = (
  SELECT string_agg(
           substr(
             '23456789ACDEFHJKMNPRTUVWXY',
             1 + mod(
                   ('x' || substr(md5("User"."id"::text || 'friend-code' || gs::text), 1, 6))::bit(24)::int,
                   26
                 ),
             1
           ),
           '' ORDER BY gs
         )
  FROM generate_series(1, 8) AS gs
);

ALTER TABLE "User" ALTER COLUMN "friendCode" SET NOT NULL;

-- L'unicité porte la sémantique « une identité pour toujours ». Sur les
-- volumes actuels une collision md5 tronquée est invraisemblable ; si elle
-- survenait, la migration échoue proprement et se relance.
CREATE UNIQUE INDEX "User_friendCode_key" ON "User"("friendCode");

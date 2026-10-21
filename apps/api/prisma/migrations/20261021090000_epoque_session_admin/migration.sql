-- Époque de session des comptes d'administration : un jeton admin porte
-- l'époque de sa signature (claim `ep`), et le garde refuse tout jeton d'une
-- autre époque. L'incrémenter révoque toutes les sessions du compte
-- (déconnexion, --reset-password, --reset-2fa), sans liste noire de jetons.
-- Les jetons déjà émis n'ont pas d'`ep` : ils sont refusés dès le déploiement,
-- chaque administrateur se reconnecte une fois.
ALTER TABLE "AdminUser" ADD COLUMN "sessionEpoch" INTEGER NOT NULL DEFAULT 0;

/**
 * Valeurs de SECRETS publiées dans le dépôt : celles des exemples de
 * développement (`apps/api/.env.example`, `.env.example`, défauts de
 * `docker-compose.yml`). Assez longues pour passer Zod, elles feraient
 * démarrer une production qui signe ses jetons, ou ouvre sa base, avec une
 * chaîne que tout lecteur du dépôt connaît.
 *
 * Refusées en production partout où elles apparaissent, même au milieu
 * d'une valeur (le mot de passe PostgreSQL vit dans `DATABASE_URL`) : par
 * l'API au démarrage (`env.production.ts`) et par `carlysctl doctor`
 * (`scripts/server/_envcheck.sh`), qui lit CE fichier — une valeur par ligne,
 * entre apostrophes : garder ce format.
 *
 * Les gabarits `CHANGE_MOI_…` ont leur propre contrôle, plus large. La liste
 * est tenue par `env.schema.spec.ts` : un secret publié par un exemple et
 * absent d'ici fait échouer le test.
 */
export const PUBLISHED_DEVELOPMENT_SECRETS: readonly string[] = [
  'secret-jwt-de-developpement-a-remplacer-absolument',
  'cle-empreintes-de-developpement-a-remplacer',
  'jeton-factice-a-remplacer',
  'whsec_valeur_factice_de_developpement',
  'rcsec_valeur_factice_de_developpement',
  'sk_test_valeur_factice_de_developpement',
  'carlys_dev_password',
  'carlys-dev-secret',
];

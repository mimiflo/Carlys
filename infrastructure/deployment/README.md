# Déploiement

Stratégie de déploiement de Carlys — cadre posé à l'Étape 1, mise en œuvre
avec la première release.

## Environnements

| Environnement | Rôle                          | Base de données     | Déploiement            |
| ------------- | ----------------------------- | ------------------- | ---------------------- |
| development   | poste développeur             | Docker local        | manuel                 |
| test          | CI                            | éphémère (services) | à chaque pipeline      |
| staging       | recette proche production     | PostgreSQL managé   | automatique depuis main|
| production    | utilisateurs réels            | PostgreSQL managé   | manuel après validation|

## Principes

- images Docker multi-stage construites en CI, taguées par SHA ;
- `prisma migrate deploy` exécuté comme étape distincte AVANT le basculement
  du trafic — jamais automatiquement au démarrage du conteneur ;
- configuration exclusivement par variables d'environnement, validée au
  démarrage (le serveur refuse de démarrer sinon) ;
- Redis managé et stockage objet (S3/Cloudflare R2) par environnement ;
- sauvegardes PostgreSQL automatiques + test de restauration régulier ;
- health checks (`/health/ready`) branchés sur l'orchestrateur ;
- pas de déploiement automatique en production sans validation humaine.

Les manifestes concrets (Terraform, fichiers de plateforme, workflows de
déploiement) seront ajoutés ici lors de la mise en place du staging.

## Pages web publiques et `PUBLIC_APP_URL`

L'application Next.js (`apps/admin`) ne sert pas que le back-office : son
groupe de routes `src/app/(public)` porte les **pages publiques du produit**,
avec leur propre mise en page (sans coquille d'administration ni lien vers
`/login`) :

| Route | Rôle |
| --- | --- |
| `/verify-email?token=…` | cible du lien de vérification d'adresse ; poste `POST /api/v1/auth/verify-email` |
| `/reset-password?token=…` | cible du lien « mot de passe oublié » ; poste `POST /api/v1/auth/reset-password` |
| `/abonnement/merci`, `/abonnement` | retours Stripe (`success_url` / `cancel_url`), statiques |
| `/privacy`, `/terms` | politique de confidentialité et conditions d'utilisation, rendues au build depuis `docs/legal/` |

En conséquence, pour chaque environnement déployé :

- **`PUBLIC_APP_URL` (API)** doit désigner l'URL publique de cette
  application web (par exemple `https://admin.carlys.example`, ou un hôte
  dédié qui proxie le même conteneur), **jamais** l'URL de l'API : c'est la
  base des liens envoyés par e-mail et des URL de retour Stripe. En local :
  `http://localhost:3001`.
- **`CORS_ORIGINS` (API)** doit contenir cette même origine : les pages
  appellent l'API depuis le navigateur.
- Le build de l'image admin lit `docs/legal/*.md` : le contexte Docker est la
  racine du dépôt et `.dockerignore` ré-inclut `docs/legal` (le conteneur
  final n'en a pas besoin : les pages sont statiques).
- Les magasins d'applications exigent une URL de politique de
  confidentialité : c'est `${PUBLIC_APP_URL}/privacy`.
- Les textes légaux portent des marqueurs `[À COMPLÉTER : …]` (raison
  sociale, adresse de contact, délais de conservation…) à renseigner avant
  toute mise en production.

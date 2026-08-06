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

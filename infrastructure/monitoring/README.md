# Monitoring

Observabilité de Carlys — état actuel et cible.

## Déjà en place (Étape 1)

- logs structurés Pino (API) avec `requestId` de corrélation ;
- `GET /health`, `GET /health/live`, `GET /health/ready` ;
- `GET /metrics` au format Prometheus (protégé par jeton en production).

## Cible

- **Sentry** : erreurs API, admin et mobile (DSN par environnement) ;
- **Prometheus + Grafana** (ou équivalent managé) : scrape de `/metrics`,
  tableaux de bord latence/erreurs/saturation ;
- **Alerting** : réveil sur readiness en échec, taux d'erreurs 5xx,
  retards des files BullMQ ;
- **Audit** : flux distinct des logs techniques (module `audit` de l'API).

Les manifestes (docker-compose de monitoring, dashboards Grafana) seront
ajoutés ici lorsque le déploiement staging sera mis en place.

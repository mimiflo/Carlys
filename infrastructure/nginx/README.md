# Nginx — reverse proxy (staging / production)

Emplacement de la configuration Nginx pour les environnements déployés :

- terminaison TLS (certificats certbot aux chemins indiqués dans l'exemple),
  redirection systématique de HTTP vers HTTPS, `ssl_protocols TLSv1.2 TLSv1.3`
  et HSTS posé par Nginx (helmet ne le pose que sur les réponses qui
  atteignent l'API) ;
- reverse proxy vers l'API (`/api`, `/health`) et l'admin, avec les en-têtes
  `X-Forwarded-*` ; l'API doit tourner avec `TRUST_PROXY_HOPS=1` pour lire
  l'adresse du client dans `X-Forwarded-For`
  (`docs/security/reverse-proxy.md`) ;
- limites de taille alignées sur l'API : `1m` pour les corps JSON
  (`MAX_JSON_BODY_SIZE`), `64m` sur `/api/v1/admin/media` (plafond de
  transport `MEDIA_TRANSPORT_HARD_CAP_BYTES` ; le plafond métier
  `MEDIA_MAX_UPLOAD_BYTES` reste appliqué par l'API, avec son enveloppe
  d'erreur). Ces valeurs bougent avec celles du code, jamais seules ;
- `/metrics` refusé publiquement.

En développement local, Nginx n'est pas nécessaire : l'API (3000) et
l'admin (3001) sont exposés directement.

`carlys.conf.example` se charge tel quel (`nginx -t`) une fois les
certificats en place ; adapter les noms de domaine et les upstreams par
environnement.

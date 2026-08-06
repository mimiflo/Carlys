# Nginx — reverse proxy (staging / production)

Emplacement de la configuration Nginx pour les environnements déployés :

- terminaison TLS (certificats gérés par l'hébergeur ou certbot) ;
- reverse proxy vers l'API (`/api`, `/health`) et l'admin ;
- compression, en-têtes de sécurité complémentaires, limites de taille.

En développement local, Nginx n'est pas nécessaire : l'API (3000) et
l'admin (3001) sont exposés directement.

`carlys.conf.example` sert de base — à adapter par environnement lors de la
mise en place du déploiement (Étape 7+).

# Derrière un reverse proxy : adresse du client, TLS, limites

> **Statut : en place.** Variable `TRUST_PROXY_HOPS`
> (`apps/api/src/config/env.schema.ts`), réglage appliqué dans
> `apps/api/src/app/configure-app.ts`, exemple Nginx dans
> `infrastructure/nginx/carlys.conf.example`, test e2e
> `apps/api/test/trust-proxy.e2e-spec.ts`.

En production, l'API ne parle jamais directement au client : un terminateur
TLS (Nginx, ingress, équilibreur) se tient devant elle. Tout ce qui, dans
l'API, raisonne sur « l'adresse du client » dépend donc de ce que ce proxy
transmet, et de la confiance qu'on lui accorde.

## 1. Adresse du client : `TRUST_PROXY_HOPS`

Trois mécanismes lisent `request.ip` :

- le **rate limiting** (`@nestjs/throttler`, tracker par défaut `req.ip`) :
  le seau global de 100 requêtes / 60 s et les seaux stricts de 10 / 60 s sur
  `login`, `register`, `verify-email`, `forgot-password`, `reset-password`
  et `admin/auth/login` ;
- les **sessions** (adresse d'ouverture, visible dans « Appareils
  connectés ») ;
- le **journal d'audit** (connexions, échecs, suspensions, attributions de
  droits, actions d'administration).

Sans réglage, Express ne fait confiance à aucun en-tête : `request.ip` est
l'adresse de la socket, c'est-à-dire **celle du proxy pour tout le trafic**.
Conséquences : un seul seau de limitation partagé par toute la plateforme
(onze connexions par minute et tout le monde reçoit 429), aucune distinction
entre un attaquant et un utilisateur, et un journal d'audit qui n'enregistre
que l'adresse de l'équilibreur.

`TRUST_PROXY_HOPS` (entier ≥ 0, défaut `0`) est le **nombre de proxys de
confiance** devant l'API :

| Déploiement                         | Valeur |
| ----------------------------------- | ------ |
| Développement local, tests          | `0`    |
| Un Nginx (ou un ingress) unique     | `1`    |
| CDN puis Nginx, tous deux maîtrisés | `2`    |

Express reconstitue la chaîne des adresses (`X-Forwarded-For` de gauche à
droite, puis l'adresse de la socket), écarte les `n` dernières (les proxys de
confiance) et retient la précédente. Avec `n = 1`, c'est donc la dernière
adresse que **le proxy lui-même** a ajoutée à `X-Forwarded-For`, jamais une
valeur que le client aurait glissée dans l'en-tête. La valeur `true` (« faire confiance à tout »)
n'existe pas dans le schéma : elle accepterait un `X-Forwarded-For`
entièrement forgé et rendrait la limitation contournable à volonté. Une
valeur plus grande que le nombre réel de proxys a le même effet : ne
déclarer que les sauts qui existent.

Côté proxy, la configuration correspondante (voir l'exemple Nginx) :

```nginx
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Real-IP         $remote_addr;
```

Le test e2e vérifie les deux cas : avec un saut, une inscription envoyée
avec `X-Forwarded-For: 203.0.113.9` ouvre une session dont l'adresse est
`203.0.113.9` ; avec zéro saut, l'en-tête est ignoré et l'adresse retenue est
celle de la socket.

## 2. Environnement de production : ce que le schéma exige

Toutes les variables d'infrastructure portent un défaut de développement
(MinIO local, Mailpit, `http://localhost:…`) pour que l'API démarre sur un
poste sans configuration. Avec `NODE_ENV=production`, ces défauts deviennent
des **erreurs de démarrage** (`apps/api/src/config/env.production.ts`) :

| Variable                                     | Exigence en production                                 |
| -------------------------------------------- | ------------------------------------------------------ |
| `S3_ENDPOINT`, `SMTP_HOST`, `EMAIL_FROM`     | fournis explicitement (valeur de développement refusée) |
| `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`   | fournis, et jamais `carlys-dev*`                       |
| `S3_PUBLIC_BASE_URL`, `PUBLIC_APP_URL`       | fournis, en `https://`, sans `localhost` ni `127.0.0.1` |
| `CORS_ORIGINS`                               | fourni, sans `localhost` ni `127.0.0.1`                |

Le message d'erreur nomme chaque variable en défaut. Les autres
environnements (`development`, `test`, `staging`) gardent leurs défauts : le
poste de développement et la CI ne changent pas de comportement.

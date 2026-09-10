# Derrière deux reverse proxys : adresse du client, HTTPS, limites

> **Statut : en place.** Variable `TRUST_PROXY_HOPS`
> (`apps/api/src/config/env.schema.ts`), réglage appliqué dans
> `apps/api/src/app/configure-app.ts`, en-têtes de proxy partagés dans
> `infrastructure/nginx/snippets/carlys-proxy.conf`, vhosts dans
> `infrastructure/nginx/` (`carlys-production.conf.example`,
> `carlys-staging.conf.example`, l'attrape-tout
> `carlys-attrape-tout.conf.example`), valeurs déployées dans
> `infrastructure/server/env/{staging,production}.env.example`, test e2e
> `apps/api/test/trust-proxy.e2e-spec.ts`.

Ce document est la référence sur le sujet : ce que l'API croit savoir de son
client, d'où elle le tient, et à quelles conditions c'est vrai.

## 1. La chaîne réelle : deux proxys, un seul terminateur TLS

```text
Internet / mobile / navigateur
      │  HTTPS 443
      ▼
gra6.luuc.fr                    ← TERMINE LE TLS, détient les certificats
      │  HTTP interne
      ▼
172.16.0.158:80                 ← serveur Carlys
      │
Nginx Carlys (écoute en HTTP sur 80 uniquement)
      │
      ▼
services Docker sur 127.0.0.1   (API 3000-3019/3100-3119, admin 3050/3150,
                                 MinIO 9000/9200)
```

Les six noms publics — `api.`, `app.`, `media.` en production, leurs jumeaux
`-staging` en recette — pointent en DNS vers **gra6**, jamais vers la machine
Carlys. Le serveur Carlys ne génère donc aucun certificat, n'installe pas
Certbot, ne sert aucun défi ACME, n'écoute pas en 443 et ne redirige rien
localement de HTTP vers HTTPS : il n'a rien à obtenir ni à renouveler.

**HTTPS n'a pas disparu, il est terminé un cran plus haut.** Toutes les URL
publiques restent en `https://` — `PUBLIC_APP_URL`, `CORS_ORIGINS`,
`S3_PUBLIC_BASE_URL`, `CARLYS_API_BASE_URL`, `CARLYS_PUBLIC_WEB_BASE_URL`. Que
le trajet gra6 → Carlys soit en clair ne doit **jamais** produire un `http://`
côté client ; la section 4 dit par quoi cette promesse tient.

Ce qui n'a pas bougé pour autant : les six `server_name`, le routage vers
l'API / l'admin / MinIO, et toutes les protections applicables derrière un
proxy (HSTS, en-têtes, refus de `/metrics`, fermeture de la racine du bucket,
limites de taille de corps) — section 6.

## 2. L'adresse du client : `TRUST_PROXY_HOPS=2`

### Qui lit `request.ip`, et pour quoi

- le **rate limiting** (`@nestjs/throttler`, tracker par défaut `req.ip`) :
  seau global de 100 requêtes / 60 s, et SEPT seaux stricts de 10 / 60 s :
  `login`, `register`, `verify-email`, `forgot-password`,
  `reset-password`, `admin/auth/login` — et `POST community/requests`,
  souvent oublié parce qu'il porte un autre nom de constante
  (`FRIEND_REQUEST_THROTTLE`) pour des valeurs identiques ;
- l'**audit et les sessions** : `request.ip` est lu à **six endroits** de
  `apps/api/src` — `clientContextOf`
  (`common/types/authenticated-request.ts`), qui alimente à la fois l'adresse
  d'ouverture d'une session (visible dans « Appareils connectés ») et le
  journal d'audit, plus cinq points d'audit d'administration
  (`admin-users.controller.ts` deux fois, `admin-community.controller.ts`,
  `catalog-actor.ts`, `media.controller.ts`).

À noter pour ne pas se tromper de garde-fou : le **verrouillage de compte**
(`LockoutService`, `AUTH_MAX_LOGIN_ATTEMPTS`) est indexé par **adresse
e-mail**, pas par adresse IP — `auth.service.ts` appelle `lockout.status(email)`
et l'admin `adminLockoutIdentifier(email)`. Une usurpation d'adresse ne le
contourne pas directement ; elle contourne le throttler, qui est ce qui protège
le verrouillage d'être atteint depuis mille adresses à la fois.

### Le réglage

Sans réglage, Express ne fait confiance à aucun en-tête : `request.ip` est
l'adresse de la socket, c'est-à-dire **celle du Nginx Carlys pour tout le
trafic**. Un seul seau de limitation pour toute la plateforme, aucune
distinction entre un attaquant et un utilisateur, un journal d'audit qui
n'enregistre qu'une adresse de boucle locale.

`TRUST_PROXY_HOPS` (entier ≥ 0, défaut `0`) est le **nombre de proxys de
confiance** devant l'API. Express reconstitue la chaîne (`X-Forwarded-For` de
gauche à droite, puis l'adresse de la socket), écarte les `n` dernières entrées
et retient la précédente.

| Déploiement                                          | Valeur |
| ---------------------------------------------------- | ------ |
| Développement local, tests                           | `0`    |
| Serveur Carlys : gra6 **puis** Nginx Carlys          | `2`    |

**Mesuré, pas déduit.** Chaîne montée pour de vrai en trois conteneurs
(client → Nginx « gra6 » → Nginx « carlys » → Express 5.2.1 avec
`app.set('trust proxy', n)`, soit exactement ce que fait
`apps/api/src/app/configure-app.ts:20`), client honnête, gra6 posant
`X-Forwarded-For` :

| `TRUST_PROXY_HOPS` | `req.ip` vaut          | Verdict                              |
| ------------------ | ---------------------- | ------------------------------------ |
| `1`                | l'adresse de **gra6**  | ✗ tout le monde partage une adresse  |
| `2`                | l'adresse du **client** | ✓                                   |
| `3`                | identique à `2`        | la liste est saturée                 |

D'où **`2`** dans les deux fichiers d'environnement. La valeur `1` était juste
tant que le Nginx Carlys était seul en façade ; elle ferait maintenant compter
tout Internet comme une seule adresse — et c'est une panne silencieuse : rien
ne casse, la limitation de débit se contente de frapper tout le monde
ensemble.

La valeur `true` (« faire confiance à tout ») n'existe pas dans le schéma Zod :
elle accepterait un `X-Forwarded-For` entièrement forgé. Mais, comme le montre
la section suivante, **un nombre de sauts n'est pas non plus une protection** :
ne déclarer que les sauts qui existent est nécessaire, ce n'est pas suffisant.

Le test e2e `trust-proxy.e2e-spec.ts` exerce le mécanisme sur un seul saut :
sans saut de confiance, un `X-Forwarded-For: 203.0.113.9` est ignoré et
l'adresse retenue est celle de la socket ; avec un saut, c'est la dernière
entrée de l'en-tête qui fait foi. C'est bien la même règle de comptage par la
droite qui donne `2` sur la chaîne réelle.

## 3. Le prérequis sur gra6 : ÉCRASER `X-Forwarded-For`, jamais l'ajouter

Ce n'est pas une hypothèse de travail dont on suppose qu'elle est remplie :
c'est une **exigence à vérifier dans la configuration de gra6**, et c'est elle,
pas `TRUST_PROXY_HOPS`, qui porte la sécurité de l'adresse du client.

Mesuré sur la même chaîne à trois conteneurs, avec un client qui **forge**
lui-même `X-Forwarded-For: 1.2.3.4` :

| Ce que gra6 pose                              | L'API voit                      | Elle retient  | Verdict     |
| --------------------------------------------- | ------------------------------- | ------------- | ----------- |
| `X-Forwarded-For $proxy_add_x_forwarded_for`  | `1.2.3.4, <client>, <gra6>`     | `1.2.3.4`     | ✗ **forgé** |
| `X-Forwarded-For $http_x_forwarded_for`       | `1.2.3.4, <gra6>`               | `1.2.3.4`     | ✗ **forgé** |
| `X-Forwarded-For $remote_addr`                | `<client>, <gra6>`              | `<client>`    | ✓ **sûr**   |

Vérifié aussi avec un `X-Forwarded-For: 9.9.9.9, 8.8.8.8` forgé : écrasé de la
même façon.

**La raison, et elle vaut d'être retenue :** un compteur de sauts numérique ne
retire des entrées **que par la droite**. Tout ce qu'un client **préfixe**
survit, quel que soit le nombre de sauts — augmenter `TRUST_PROXY_HOPS` n'y
change rien, cela ne fait que sauter des entrées supplémentaires par la droite,
donc revenir plus près encore de ce que le client a écrit. La protection ne
vient donc pas de l'API : elle vient de gra6.

Ce que le vhost de gra6 qui sert les six noms Carlys doit poser :

```nginx
proxy_set_header Host              $host;         # conserver le Host original
proxy_set_header X-Forwarded-For   $remote_addr;  # ÉCRASER, jamais ajouter
proxy_set_header X-Forwarded-Proto https;
```

Si gra6 **ajoute** au lieu d'**écraser**, n'importe quel client se fait passer
pour n'importe quelle adresse : limitation de débit contournée et journal
d'audit empoisonné — et un journal
d'audit empoisonné est pire qu'un journal absent, parce qu'on le croit.

Le Nginx Carlys, lui, garde volontairement `$proxy_add_x_forwarded_for`
(`snippets/carlys-proxy.conf`) : il **ajoute** l'adresse de gra6 à la suite de
ce que gra6 a écrit, et c'est cet ajout qui constitue le second saut compté par
`TRUST_PROXY_HOPS=2`. Les deux réglages ne valent que l'un par l'autre, et
seulement si gra6 écrase.

## 4. `X-Forwarded-Proto: https` en dur — et le pare-feu qui en est le corollaire

Le Nginx Carlys pose `X-Forwarded-Proto: https` **en dur**. Ni `$scheme`, qui
vaudrait `http` puisque gra6 lui parle en clair ; ni `$http_x_forwarded_proto`,
dont on ne suppose rien — c'est du texte fourni par la requête entrante. Le
client, lui, a bien parlé HTTPS à gra6 : c'est cela que l'en-tête décrit.

Mesuré sur la chaîne à trois conteneurs : avec cette ligne, l'API voit
`req.protocol = 'https'` et `req.secure = true` alors que tout le trajet
interne est en clair. C'est ce qui garantit le point « les URL publiques
restent en `https://` » de la section 1.

**Corollaire de sécurité, à traiter comme un prérequis de pare-feu et non comme
une option : le port 80 du serveur Carlys ne doit être joignable QUE depuis
gra6.** Sinon n'importe qui obtient de l'API un `req.secure = true` mensonger
— et surtout s'adresse à elle sans être passé par l'écrasement de
`X-Forwarded-For` de la section 3, ce qui rend cette protection nulle. Le vhost
attrape-tout (`return 444` sur tout `Host` inconnu) est une **seconde couche**,
pas la garde principale : un client qui tape l'IP en direct en écrivant
`Host: api.carlys.app` atteint le vhost de l'API, pas l'attrape-tout.

**Où se situe le risque, aujourd'hui.** Aucun fichier de `apps/api/src` ne lit
`req.protocol` ni `req.secure` (vérifié par recherche) : `X-Forwarded-Proto`
est une garantie d'avenir, et l'assurance que rien ne fabriquera une URL en
clair. C'est `X-Forwarded-For` qui porte le risque du jour, puisque c'est lui
que lisent le throttler et les six points d'audit de la section 2.

## 5. Environnement de production : ce que le schéma exige

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

L'exigence `https://` sur les URL publiques n'est pas contredite par le HTTP
interne : elle porte sur ce que le client contacte, c'est-à-dire gra6. La
recette pose `NODE_ENV=production` elle aussi, précisément pour échouer comme
la production.

Le message d'erreur nomme chaque variable en défaut. Les autres environnements
(`development`, `test`, `staging` au sens de `NODE_ENV`) gardent leurs
défauts : le poste de développement et la CI ne changent pas de comportement.

## 6. Ce que les vhosts Carlys garantissent encore

`carlys-production.conf.example` et son jumeau de recette
`carlys-staging.conf.example` n'ont plus ni `listen 443`, ni
`ssl_certificate`, ni redirection HTTP → HTTPS, ni
`/.well-known/acme-challenge/`. Ils partagent leurs en-têtes de proxy par
`snippets/carlys-proxy.conf`, pour que les sections 2 à 4 restent vraies sur
les six vhosts à la fois. Ce qui reste, et pourquoi :

- **HSTS posé par Nginx** (`Strict-Transport-Security`, un an,
  `includeSubDomains`). Un en-tête de *réponse* traverse gra6 jusqu'au
  navigateur, qui l'applique à l'origine `https://` qu'il a réellement
  contactée : le poser ici garde son sens même si le TLS est ailleurs. Il
  protège si gra6 oublie de le faire, et couvre les réponses que Nginx produit
  lui-même (404, 413) comme tout le vhost `media`, que helmet ne voit jamais.
- **Limites de corps alignées sur le code**, jamais devinées :
  - `client_max_body_size 1m` au niveau du serveur, soit `MAX_JSON_BODY_SIZE`
    (`'1mb'`, `packages/shared-config`) ;
  - `client_max_body_size 64m` sur `/api/v1/admin/media`, soit
    `MEDIA_TRANSPORT_HARD_CAP_BYTES` (`packages/api-contracts/src/media.ts`).
    Le plafond **métier** (`MEDIA_MAX_UPLOAD_BYTES`, 20 Mio par défaut, réglable
    par environnement) est appliqué par l'API, qui répond `413` **avec**
    l'enveloppe `{ error: { code, message, … } }` : Nginx ne doit jamais couper
    avant elle, sinon l'admin reçoit un `413` brut, non interprétable.
- **`/metrics` refusé** publiquement (403) : le collecteur l'interroge sur la
  boucle locale.
- **Le vhost des médias n'expose que le bucket public.** Proxifier `/` vers
  MinIO rendrait publiques la racine de son API S3 et sa console
  d'administration : seul le préfixe `/carlys-media/` est proxifié, la racine
  du bucket répond `404`, le reste aussi. Les méthodes autres que `GET` et
  `HEAD` y sont refusées (`limit_except`) — les dépôts passent par l'API,
  jamais par cet hôte —, et les cookies sont effacés dans les deux sens : un
  média public n'a pas d'identité, et un `Set-Cookie` renvoyé par l'amont
  rendrait la réponse non mutualisable par les caches.
- **La recette n'est pas indexable** : `X-Robots-Tag: noindex, nofollow,
  noarchive` sur chaque réponse et un `robots.txt` servi par Nginx. Sans cela,
  un `/privacy` de recette peut être référencé à la place de celui de
  production, et les données de test restent cherchables après leur
  effacement.
- **Aucun hôte inconnu ne tombe sur un vhost Carlys** : l'attrape-tout reprend
  la place de `default_server` et ferme la connexion (`return 444`). Sans lui,
  Nginx élirait comme défaut le premier bloc rencontré — l'API de production.

## 7. Vérifier

```bash
# Sur le serveur Carlys : la configuration se charge sans certificat préalable.
sudo nginx -t && sudo systemctl reload nginx

# Les deux .env déployés doivent porter 2, pas 1.
grep -n '^TRUST_PROXY_HOPS=' /srv/carlys/staging/.env /srv/carlys/production/.env

# Sur gra6 : l'en-tête doit être ÉCRASÉ (section 3). Un $proxy_add_… ou un
# $http_… ici est une faille, pas un détail de style.
grep -rn 'X-Forwarded-For' /etc/nginx/sites-enabled/
```

Le contrôle qui vaut tous les autres, une fois la chaîne en place : forger
l'en-tête depuis l'extérieur et relire l'adresse retenue.

```bash
curl -sS https://api.carlys.app/api/v1/… -H 'X-Forwarded-For: 1.2.3.4'
```

Si `1.2.3.4` apparaît dans la session ouverte ou dans le journal d'audit, gra6
**ajoute** au lieu d'écraser : la section 3 n'est pas satisfaite, et la
limitation de débit comme l'audit sont contournables.

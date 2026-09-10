# Nginx — reverse proxy (recette / production)

Nginx tourne sur **l'hôte**, pas dans un conteneur. Tout le reste de Carlys —
API, admin, MinIO — n'écoute que sur la boucle locale, et PostgreSQL et Redis
ne publient aucun port du tout.

## Où ce Nginx se situe : il ne termine plus le TLS

```
Internet / mobile / navigateur
      │ HTTPS 443
      ▼
reverse proxy réseau  gra6.luuc.fr      ← termine le TLS, détient les certificats
      │ HTTP interne
      ▼
serveur Carlys  172.16.0.158:80
      │
      ▼
Nginx Carlys (ces fichiers) — HTTP sur le port 80, uniquement
      │
      ▼
services Docker sur 127.0.0.1
```

Les six noms publics pointent en DNS vers **gra6**, jamais vers cette machine :

| | production | recette |
| - | ---------- | ------- |
| API | `api.DOMAINE` | `api-staging.DOMAINE` |
| Web | `app.DOMAINE` | `app-staging.DOMAINE` |
| Médias | `media.DOMAINE` | `media-staging.DOMAINE` |

Ce que cela retire de ces fichiers : aucun `listen 443`, aucun
`ssl_certificate`, aucune redirection HTTP → HTTPS, aucun
`/.well-known/acme-challenge/`. **Rien à obtenir, rien à renouveler, aucun
certbot à installer sur ce serveur** : les certificats publics ne lui
appartiennent pas.

Ce que cela ne change pas : les `server_name`, le routage, les limites de
taille, le refus de `/metrics`, la fermeture de la racine du bucket, les
en-têtes de sécurité — et **les URL publiques, qui restent en `https://`**
(`PUBLIC_APP_URL`, `CORS_ORIGINS`, `S3_PUBLIC_BASE_URL`, `CARLYS_API_BASE_URL`,
`CARLYS_PUBLIC_WEB_BASE_URL`). HTTPS existe toujours pour le client ; il est
seulement terminé un cran plus haut. Le fait que gra6 → Carlys soit en clair ne
doit jamais produire un `http://`.

## Les fichiers

| Fichier | Rôle |
| ------- | ---- |
| `snippets/carlys-proxy.conf` | en-têtes de proxy, partagés par les six vhosts |
| `carlys-production.conf.example` | `api.` / `app.` / `media.` → 3000 / 3001 / 9000 |
| `carlys-staging.conf.example` | `api-staging.` / `app-staging.` / `media-staging.` → 3100 / 3101 / 9200 |
| `carlys-attrape-tout.conf.example` | le `default_server` du port 80 : tout nom d'hôte qu'on ne sert pas |

Les deux fichiers d'environnement sont indépendants : on peut n'activer que la
recette, puis ajouter la production quand ses DNS existent — il n'y a plus
d'étape « certificats » à attendre. Le snippet, lui, est requis par les deux.
L'attrape-tout est indépendant des trois autres et ne demande plus rien à
générer au préalable : il s'active seul, dès le premier environnement.

Installation, remplacement du domaine et ordre des opérations :
**[le guide de mise en route](../../docs/deployment/mise-en-route-serveur.md)**.

## Deux prérequis hors de ces fichiers — à vérifier, pas à supposer

Ces fichiers ne sont corrects que si la machine et gra6 tiennent deux
engagements qu'aucun `nginx -t` ne peut contrôler.

**1. Le port 80 de cette machine n'est joignable que depuis gra6.**
`snippets/carlys-proxy.conf` pose `X-Forwarded-Proto: https` en dur ; l'API voit
donc `req.secure = true` alors que tout le trajet interne est en clair. C'est
ce qui garantit que les URL publiques restent en `https://` — et c'est ce qui
rend le pare-feu obligatoire : sans lui, n'importe qui obtient ce
`req.secure = true` mensonger, et surtout parle à l'API sans être passé par le
point 2.

**2. Sur gra6, dans le vhost qui sert les six noms Carlys :**

```nginx
proxy_set_header Host              $host;         # conserver le Host original
proxy_set_header X-Forwarded-For   $remote_addr;  # ÉCRASER, jamais ajouter
proxy_set_header X-Forwarded-Proto https;
```

Si gra6 **ajoute** au lieu d'**écraser**, n'importe quel client se fait passer
pour n'importe quelle adresse : limitation de débit contournée et journal
d'audit empoisonné. Le raisonnement complet, les
mesures et le pourquoi (un compteur de sauts numérique ne retire des entrées
que par la droite ; ce qu'un client préfixe survit) sont dans
`snippets/carlys-proxy.conf` et dans `docs/security/reverse-proxy.md`.

## Ce que ces fichiers garantissent

- **En-têtes de sécurité conservés bien que le TLS soit ailleurs.** HSTS est un
  en-tête de *réponse* : il traverse gra6 jusqu'au navigateur, qui l'applique à
  l'origine `https://` qu'il a réellement contactée. Le poser ici protège si
  gra6 oublie de le faire, et couvre les réponses que Nginx produit lui-même
  (404, 413) comme tout ce que sert le vhost `media` — que helmet, côté API, ne
  voit jamais.
- **Adresse du client** transmise en `X-Forwarded-For` par
  `snippets/carlys-proxy.conf`, qui **ajoute** l'adresse de gra6 à ce que gra6 a
  écrit. Il y a deux proxys dans la chaîne, donc l'API doit tourner avec
  **`TRUST_PROXY_HOPS=2`** (c'était 1 quand ce Nginx était seul en façade ; à 1,
  `req.ip` vaudrait l'adresse de gra6 pour tout le trafic). Les deux réglages ne
  valent que l'un par l'autre, et seulement si gra6 écrase l'en-tête — voir
  ci-dessus.
- **Limites de taille alignées sur le code**, jamais devinées : `1m` pour les
  corps JSON (`MAX_JSON_BODY_SIZE`), `64m` sur `/api/v1/admin/media`
  (`MEDIA_TRANSPORT_HARD_CAP_BYTES`). Nginx s'aligne sur le plafond de
  transport et non sur `MEDIA_MAX_UPLOAD_BYTES`, qui est réglable par
  environnement : c'est l'API qui doit refuser un fichier trop lourd, avec son
  enveloppe d'erreur, et Nginx qui ne doit jamais couper avant elle.
- **`/metrics` refusé** publiquement : le collecteur l'interroge sur la boucle
  locale.
- **Médias en lecture seule.** Le vhost `media` n'expose que le préfixe du
  bucket public (`/carlys-media/`) — jamais la racine de l'API S3 de MinIO —,
  refuse toute méthode autre que `GET`/`HEAD`, efface les cookies dans les deux
  sens et sert avec un cache long (`immutable` : une clé d'objet est
  `<kind>/<uuid>.<extension>`, son contenu ne change jamais).
- **Recette non indexable** : `X-Robots-Tag` sur chaque réponse et un
  `robots.txt` servi par Nginx. Un mot de passe HTTP est possible en plus, mais
  il n'est pas le défaut — le fichier de recette explique ce qu'il casse
  (liens des e-mails, liens légaux de l'application mobile) et comment
  l'activer sans les casser.
- **Aucun hôte inconnu ne tombe sur un vhost de Carlys.** Le guide fait retirer
  le vhost par défaut de la distribution ; l'attrape-tout reprend cette place et
  ferme la connexion (`return 444`). Sans lui, Nginx élirait comme défaut le
  premier bloc rencontré — l'API de production.

## HTTP/2, TLS, ACME : ce qui a quitté ces fichiers

- **HTTP/2** se négocie dans la poignée de main TLS (ALPN) : il se termine donc
  sur gra6, avec le TLS. Entre gra6 et cette machine, c'est du HTTP/1.1 en clair
  (`proxy_http_version 1.1;` dans le snippet). Plus aucun `listen … http2` ici,
  et donc plus d'arbitrage de compatibilité à tenir : la question posée par
  `http2 on;` (apparue en Nginx 1.25.1, absente du 1.22.1 de Debian 12 et du
  1.18.0 d'Ubuntu 22.04) ne se pose plus du tout.
- **ACME / certbot** : les défis `/.well-known/acme-challenge/` ne sont plus
  servis ici, ni par les vhosts nommés ni par l'attrape-tout. Les émissions et
  les renouvellements sont l'affaire de gra6.
- **Certificat auto-signé de l'attrape-tout** : disparu avec le `listen 443`.
  Son rôle a changé et le fichier l'explique — il ne protège plus d'un mauvais
  certificat, il empêche qu'un `Host` inconnu, ou une requête arrivant en direct
  sur l'IP, atteigne le premier bloc déclaré, c'est-à-dire l'API de production.
  Si `/etc/nginx/ssl/attrape-tout.{crt,key}` traîne d'une installation
  antérieure, plus rien ne le référence : il peut être supprimé.

En développement local, Nginx n'est pas nécessaire : l'API (3000) et l'admin
(3001) sont exposés directement par `docker-compose.yml`.

## Vérifier avant de recharger

```bash
sudo nginx -t && sudo systemctl reload nginx
```

`nginx -t` n'est pas une formalité : il ouvre réellement les sockets.

Ces fichiers ont été éprouvés autrement que par relecture. `nginx -t` vert sur
les **sept vhosts** (3 production + 3 recette + l'attrape-tout) avec **1.18.0,
1.22.1 et 1.27** — les deux premières étant celles d'Ubuntu 22.04 et de
Debian 12 —, et sans aucun avertissement sur 1.27, là où le `listen … http2`
d'avant en produisait un.

Puis un Nginx réellement démarré devant des doublures d'amont, pour vérifier ce
qui ne se voit pas dans le texte. Ce qui a été mesuré, avec un `Host:` posé à la
main sur chaque requête :

| Requête | Résultat |
| ------- | -------- |
| `GET /api/v1/…` sur `api.` | atteint l'amont avec `X-Forwarded-Proto: https` et `X-Forwarded-Port: 443`, alors que la requête est arrivée en clair sur le port 80 |
| `GET /metrics` sur `api.` | 403 |
| `GET /` sur `api.` | 404 |
| `GET /_next/static/x.js` sur `app.` | `Cache-Control: …immutable` **et** HSTS ensemble (`add_header` REMPLACE les en-têtes hérités dès qu'on en ajoute un dans une `location` — d'où les répétitions apparentes) |
| `GET /carlys-media/` sur `media.` | 404 (racine du bucket fermée) |
| `GET /carlys-media/avatar/abc.png` | le `Set-Cookie` posé par la doublure MinIO n'atteint pas le client |
| `PUT /carlys-media/avatar/abc.png` | 403 |
| `GET /robots.txt` sur `app-staging.` | `User-agent: * / Disallow: /` |
| `Host: inconnu.example`, et une requête sur l'IP sans `Host` servi | connexion fermée sans réponse (curl : « Empty reply from server ») |

Enfin la chaîne des deux proxys, montée avec une doublure de gra6 en tête, pour
mesurer ce que l'API reçoit réellement quand le client **forge** son propre
`X-Forwarded-For: 1.2.3.4` :

| gra6 pose | l'amont voit | verdict |
| --------- | ------------ | ------- |
| `X-Forwarded-For $remote_addr` (écrase) | `<client>, <gra6>` — le `1.2.3.4` a disparu | ✅ sûr |
| `X-Forwarded-For $proxy_add_x_forwarded_for` (ajoute) | `1.2.3.4, <client>, <gra6>` — le forgé est là, et c'est lui que `TRUST_PROXY_HOPS=2` retiendrait | ❌ |

Même résultat avec un `X-Forwarded-For: 9.9.9.9, 8.8.8.8` forgé : écrasé de la
même façon. C'est la mesure qui fait du point 2 des prérequis une **exigence**
et non une recommandation.

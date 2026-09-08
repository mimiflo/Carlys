# Nginx — reverse proxy (recette / production)

Nginx tourne sur **l'hôte**, pas dans un conteneur : il est le seul processus
exposé publiquement. Tout le reste de Carlys — API, admin, MinIO — n'écoute
que sur la boucle locale, et PostgreSQL et Redis ne publient aucun port du
tout.

## Les fichiers

| Fichier | Rôle |
| ------- | ---- |
| `snippets/carlys-proxy.conf` | en-têtes de proxy, partagés par les six vhosts |
| `carlys-production.conf.example` | `api.` / `app.` / `media.` → 3000 / 3001 / 9000 |
| `carlys-staging.conf.example` | `api-staging.` / `app-staging.` / `media-staging.` → 3100 / 3101 / 9200 |
| `carlys-attrape-tout.conf.example` | le `default_server` des deux ports : tout nom d'hôte qu'on ne sert pas |

Les deux fichiers d'environnement sont indépendants : on peut n'activer que la
recette, puis ajouter la production quand ses DNS et ses certificats existent.
Le snippet, lui, est requis par les deux. L'attrape-tout est indépendant des
trois autres et ne référence aucun certificat Let's Encrypt : il s'active
seul, dès le premier environnement.

Installation, remplacement du domaine et ordre des opérations (DNS →
certificats → activation) : **[le guide de mise en route](../../docs/deployment/mise-en-route-serveur.md)**.

## Ce que ces fichiers garantissent

- **TLS** aux chemins certbot, redirection systématique de HTTP vers HTTPS
  (`/.well-known/acme-challenge/` restant en clair pour le renouvellement),
  `ssl_protocols TLSv1.2 TLSv1.3`, et HSTS posé par Nginx — helmet ne le pose
  que sur les réponses qui atteignent l'API.
- **Adresse du client** transmise en `X-Forwarded-For` par
  `snippets/carlys-proxy.conf`. L'API doit tourner avec `TRUST_PROXY_HOPS=1` :
  les deux réglages ne valent que l'un par l'autre
  (`docs/security/reverse-proxy.md`).
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
  premier bloc rencontré — l'API de production —, qui répondrait sous le
  certificat d'`api.DOMAINE`.

## Compatibilité : `listen … http2`, pas `http2 on;`

Ces fichiers écrivent `listen 443 ssl http2;`. La directive `http2 on;`, plus
récente et plus jolie, **n'existe que depuis Nginx 1.25.1** — alors que le
guide de mise en route vise Debian 12 (Nginx **1.22.1**) et Ubuntu 22.04
(**1.18.0**), et que `setup.sh` installe le Nginx de la distribution. Sur ces
machines, `http2 on;` ne dégrade pas HTTP/2 : elle fait échouer `nginx -t` sur
`unknown directive "http2"`, donc **rien ne démarre**. À l'inverse, le
paramètre `http2` de `listen` fonctionne depuis 1.9.5 ; il est déprécié depuis
1.25.1, où il ne coûte qu'un avertissement au rechargement. Un avertissement
sur les Nginx récents vaut mieux qu'un refus de démarrage sur les Nginx que ce
dépôt installe.

En développement local, Nginx n'est pas nécessaire : l'API (3000) et l'admin
(3001) sont exposés directement par `docker-compose.yml`.

## Vérifier avant de recharger

`nginx -t` n'est pas une formalité : il ouvre réellement les sockets et lit
réellement les certificats.

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Ces fichiers ont été éprouvés autrement que par relecture : `nginx -t` vert sur
les sept vhosts avec **1.18.0, 1.22.1 et 1.27** — les deux premières étant
précisément celles d'Ubuntu 22.04 et de Debian 12, que le guide dit installer.
Puis un Nginx réellement démarré devant des doublures d'amont, pour vérifier ce
qui compte et qui ne se voit pas dans le texte — que `PUT` sur un média répond
403, que la racine de MinIO répond 404, que le `Set-Cookie` d'un amont
n'atteint pas le client sur `media`, que `Cache-Control` n'efface pas HSTS
(`add_header` REMPLACE les en-têtes hérités dès qu'on en ajoute un dans une
`location` — d'où les répétitions apparentes), et qu'un nom d'hôte inconnu
reçoit le certificat de l'attrape-tout (`CN=hote-inconnu`) et une connexion
fermée, là où il recevait celui d'`api.` et une réponse de l'API.

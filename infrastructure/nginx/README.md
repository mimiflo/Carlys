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

Les deux fichiers d'environnement sont indépendants : on peut n'activer que la
recette, puis ajouter la production quand ses DNS et ses certificats existent.
Le snippet, lui, est requis par les deux.

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

En développement local, Nginx n'est pas nécessaire : l'API (3000) et l'admin
(3001) sont exposés directement par `docker-compose.yml`.

## Vérifier avant de recharger

`nginx -t` n'est pas une formalité : il ouvre réellement les sockets et lit
réellement les certificats.

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Ces deux fichiers ont été éprouvés autrement que par relecture : `nginx -t`
vert sur les six vhosts, puis un Nginx réellement démarré devant des doublures
d'amont, pour vérifier ce qui compte et qui ne se voit pas dans le texte — que
`PUT` sur un média répond 403, que la racine de MinIO répond 404, que le
`Set-Cookie` d'un amont n'atteint pas le client sur `media`, et que
`Cache-Control` n'efface pas HSTS (`add_header` REMPLACE les en-têtes hérités
dès qu'on en ajoute un dans une `location` — d'où les répétitions apparentes).

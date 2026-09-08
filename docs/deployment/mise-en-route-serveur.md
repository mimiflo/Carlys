# Mettre Carlys en ligne, d'un serveur nu à l'application publiée

Ce guide se suit **de bout en bout, dans l'ordre**. Chaque étape dit ce qui
doit répondre quoi : tant que la vérification d'une étape ne passe pas, la
suivante échouera plus loin et plus obscurément.

Deux environnements cohabitent sur **un seul serveur dédié**, isolés par leur
projet Compose et leurs volumes :

| | API | Application web | Médias |
| --- | --- | --- | --- |
| **recette** | `api-staging.DOMAINE` | `app-staging.DOMAINE` | `media-staging.DOMAINE` |
| **production** | `api.DOMAINE` | `app.DOMAINE` | `media.DOMAINE` |

Dans tout ce qui suit, remplacez `carlys.example` par votre domaine réel.

> **Ce que ce guide n'automatise pas, et n'automatisera pas.** L'achat du
> domaine, les enregistrements DNS, les comptes Apple / Google Play / Samsung,
> la rédaction des textes légaux, et les vraies valeurs des secrets (Stripe,
> Firebase, Sentry, SMTP). La bascule en production reste un **geste humain** :
> c'est une règle du dépôt, pas une limite technique.

---

## 0. Ce qu'il faut avoir sous la main

- Un serveur Debian 12 ou Ubuntu 22.04+, accès `root` ou `sudo`, une adresse
  IPv4 publique (notée `203.0.113.10` dans les exemples).
- Un nom de domaine dont vous contrôlez la zone DNS.
- Un compte GitHub ayant accès au dépôt `mimiflo/Carlys`.

---

## 1. DNS — six enregistrements, à poser en premier

Rien d'autre ne peut avancer tant que les noms ne résolvent pas : certbot
refuse d'émettre un certificat pour un nom qui ne pointe pas vers le serveur
qu'il interroge.

| Type | Nom | Valeur |
| ---- | --- | ------ |
| A | `api` | `203.0.113.10` |
| A | `app` | `203.0.113.10` |
| A | `media` | `203.0.113.10` |
| A | `api-staging` | `203.0.113.10` |
| A | `app-staging` | `203.0.113.10` |
| A | `media-staging` | `203.0.113.10` |

Trois par environnement. Ajoutez les `AAAA` équivalents si le serveur a une
IPv6 — les vhosts écoutent déjà en `[::]`.

Le domaine nu (`carlys.example`) et `www` ne sont **pas** servis par ces
vhosts : aucun des six `server_name` ne les couvre. Ce qu'ils reçoivent est
décidé par le vhost **attrape-tout** posé à l'étape 6 — une connexion fermée
sans réponse, derrière un certificat auto-signé. Sans lui, Nginx désignerait
d'office comme défaut le premier bloc rencontré, c'est-à-dire l'**API de
production** : un nom inconnu atteindrait la production avec un certificat au
mauvais nom. Si vous voulez mettre un site vitrine sur le domaine nu, c'est un
vhost de plus, hors de ce guide.

**Vérification** — depuis n'importe quelle machine, une fois la propagation
faite (de quelques minutes à quelques heures) :

```bash
for h in api app media api-staging app-staging media-staging; do
  printf '%-22s %s\n' "$h" "$(dig +short "$h.carlys.example")"
done
```

Les six lignes doivent afficher l'IP du serveur. Une ligne vide = enregistrement
absent ou pas encore propagé : **attendez**, ne passez pas à la suite.

---

## 2. Préparer le serveur

Sur le serveur, en `root` :

```bash
apt-get update && apt-get install -y git
git clone https://github.com/mimiflo/Carlys.git /srv/carlys/repo
cd /srv/carlys/repo
sudo ./scripts/server/setup.sh
```

**Si le dépôt est privé**, ce `git clone` anonyme échoue sur
`Authentication failed` (ou `repository not found`, GitHub ne distinguant pas
un dépôt privé d'un dépôt inexistant). Il faut alors donner au serveur un
accès en **lecture seule**, et le choix n'est pas neutre car l'étape 10 y
revient à chaque déploiement — un `git pull` doit pouvoir se faire sans qu'un
humain saisisse quoi que ce soit :

```bash
# Option A — clé de déploiement (recommandée : liée AU DÉPÔT, pas à un compte,
# révocable seule, et sans autre droit que la lecture de ce dépôt).
ssh-keygen -t ed25519 -N '' -C 'carlys-serveur' -f /root/.ssh/carlys_deploy
cat /root/.ssh/carlys_deploy.pub
# → à coller dans GitHub → le dépôt → Settings → Deploy keys → Add deploy key,
#   SANS cocher « Allow write access ».
printf '%s\n' \
  'Host github.com' \
  '  IdentityFile /root/.ssh/carlys_deploy' \
  '  IdentitiesOnly yes' >> /root/.ssh/config
git clone git@github.com:mimiflo/Carlys.git /srv/carlys/repo

# Option B — jeton personnel, si les clés de déploiement vous sont fermées.
# Portée `repo` (lecture) ; il expire, et le jour où il expire c'est `git pull`
# qui casse, pas le déploiement — d'où la préférence pour l'option A.
#
# Le jeton ne va PAS dans l'URL du dépôt. Une URL porteuse d'identifiants se
# recopie dans .git/config en clair, reste dans l'historique du shell, et
# ressort de la moindre commande qui affiche le remote (`git remote -v`, un
# message d'erreur de `git pull`, une trace de déploiement). On le range dans
# le fichier d'identifiants de git, en 600 : `credential.helper store` le relit
# tout seul, donc le `git pull` de l'étape 10 reste non interactif.
install -m 600 /dev/null /root/.git-credentials
printf 'https://%s:%s@github.com\n' 'VOTRE_LOGIN' 'LE_JETON' > /root/.git-credentials
git config --global credential.helper store
git clone https://github.com/mimiflo/Carlys.git /srv/carlys/repo
```

Ce jeton-là n'est **pas** celui de l'étape 3 : celui-ci lit le *dépôt Git*,
celui de l'étape 3 lit les *images du registre*. Deux portées, deux fichiers,
et aucune raison de les confondre.

`setup.sh` installe Docker et le plugin Compose, Nginx, certbot, ouvre le
pare-feu sur 22/80/443 seulement, crée l'arborescence `/srv/carlys/`, y dépose
les `.env` à remplir depuis les exemples versionnés, et installe la tâche
quotidienne de sauvegarde. **Il est idempotent** : le relancer sur un serveur
déjà configuré ne casse rien et ne réécrit aucun `.env` déjà rempli.

**Vérification :**

```bash
docker --version && docker compose version   # les deux répondent
systemctl is-active nginx                    # active
ufw status | head -5                         # 22, 80, 443 seulement
ls -la /srv/carlys/                          # staging/ production/ backups/
```

---

## 3. Le jeton de lecture du registre

Les images vivent dans GHCR et le paquet est privé : le serveur doit pouvoir
les lire. Créez un **Personal Access Token (classic)** avec la seule portée
`read:packages` — https://github.com/settings/tokens.

```bash
# Sur le serveur. Le jeton ne va PAS dans un .env : il est lu par deploy.sh
# pour `docker login`, et rien d'autre n'a besoin de le voir.
printf '%s' 'CHANGE_MOI_jeton_github_read_packages' > /srv/carlys/ghcr.token
chmod 600 /srv/carlys/ghcr.token
```

**Vérification :**

```bash
docker login ghcr.io -u VOTRE_LOGIN_GITHUB --password-stdin < /srv/carlys/ghcr.token
# → "Login Succeeded"
```

---

## 4. Publier les premières images

La publication est automatique, mais elle exige **une variable de dépôt**, une
seule fois. Sans elle le workflow échoue exprès, avec un message qui explique
pourquoi.

Dans GitHub → **Settings → Secrets and variables → Actions → Variables →
New repository variable** :

| Nom | Valeur |
| --- | ------ |
| `CARLYS_DOMAIN` | `carlys.example` (le domaine **nu**, sans `https://`, sans sous-domaine) |

**Pourquoi cette variable est obligatoire, et pourquoi l'oublier ne se voit
pas.** L'image admin fige l'adresse de l'API dans le JavaScript envoyé au
navigateur : `NEXT_PUBLIC_API_BASE_URL` n'est pas lue à l'exécution, Next.js la
remplace *au build*. Une image construite sans elle contient littéralement
`http://localhost:3000` dans ses fichiers `.next/static/chunks/` — le
back-office se charge, s'affiche, et ne joint aucune API. L'image se construit,
elle démarre, et elle est morte. D'où l'échec bruyant en amont.

Poussez ensuite sur la branche de travail (ou lancez le workflow
`images-publish` à la main depuis l'onglet Actions). Il publie trois images :

```
ghcr.io/mimiflo/carlys-api:sha-<sha12>
ghcr.io/mimiflo/carlys-api-migrate:sha-<sha12>
ghcr.io/mimiflo/carlys-admin:sha-<sha12>
```

**`images-publish` tourne à CHAQUE poussée, sans filtre de chemins**, et c'est
délibéré : le déploiement se fait par SHA, donc **tout** commit de la branche
doit avoir ses images. Un filtre qui n'aurait rien publié pour un commit ne
touchant que `infrastructure/` ou `scripts/` ferait échouer `deploy.sh` sur ce
SHA — image absente —, et la cause serait invisible depuis le serveur. La
contrepartie est un peu de place dans GHCR : les vieux tags `sha-…` se purgent
depuis l'onglet **Packages** du dépôt, ils ne disparaissent pas seuls.

**Vérification** : le résumé de l'exécution affiche le `sha12` et la commande
de déploiement à copier. Notez ce `sha12`, il sert à l'étape 7.

---

## 5. Remplir les `.env`

Deux fichiers, déposés par `setup.sh`, à remplir à la main :

```bash
sudoedit /srv/carlys/staging/.env
sudoedit /srv/carlys/production/.env
```

Les exemples versionnés
(`infrastructure/server/env/{staging,production}.env.example`) contiennent
**toutes** les variables exigées par `apps/api/src/config/env.schema.ts`, avec
les URL déjà câblées sur les sous-domaines. Ce qui reste à faire : remplacer
chaque `CHANGE_MOI_…`.

### Les pièges qui font refuser le démarrage

L'API **refuse de démarrer** sur une configuration invalide, et son message
nomme chaque variable en défaut. Trois règles expliquent la quasi-totalité des
refus :

1. **`NODE_ENV=production` dans les DEUX environnements.** C'est le mode
   d'exécution de Nest, pas le nom de l'environnement. La recette est donc
   soumise **aux mêmes refus** que la production.
2. **Les valeurs de développement sont refusées.** Laisser `PUBLIC_APP_URL` à
   `http://localhost:3001`, ou une clé S3 commençant par `carlys-dev`, arrête
   le démarrage. Deux règles distinctes se cachent là : la valeur de
   développement *exacte* est refusée d'une part, le *préfixe* `carlys-dev*`
   de l'autre.
3. **Les URL publiques doivent être en `https://` et ne jamais pointer en
   local.** Les deux règles ne couvrent pas tout à fait le même ensemble, et
   `apps/api/src/config/env.production.ts` en est la source de vérité :
   « jamais en local » vaut pour `PUBLIC_APP_URL`, `S3_PUBLIC_BASE_URL` et
   `CORS_ORIGINS` ; « en `https://` » vaut pour les mêmes trois, mais
   `CORS_ORIGINS` étant une **liste séparée par des virgules**, c'est chaque
   origine qui est contrôlée — une seule entrée en clair, fût-elle la
   troisième, suffit à faire refuser le démarrage, et le message la nomme.

En revanche, ce qui **reste interne au réseau Compose** n'est pas concerné :
`S3_ENDPOINT=http://minio:9000` et `SMTP_HOST=mailpit` passent parfaitement,
en recette comme en production. Ce sont des adresses de conteneur, pas des
adresses publiques.

### Les valeurs qui doivent correspondre aux vhosts

| Variable | Recette | Production |
| --- | --- | --- |
| `PUBLIC_APP_URL` | `https://app-staging.carlys.example` | `https://app.carlys.example` |
| `CORS_ORIGINS` | `https://app-staging.carlys.example` | `https://app.carlys.example` |
| `S3_PUBLIC_BASE_URL` | `https://media-staging.carlys.example/carlys-media` | `https://media.carlys.example/carlys-media` |
| `TRUST_PROXY_HOPS` | `1` | `1` |

`PUBLIC_APP_URL` désigne l'**application web**, jamais l'API : c'est la base
des liens envoyés par e-mail et des retours Stripe. `TRUST_PROXY_HOPS=1` va de
pair avec le Nginx unique de l'étape 6 — sans lui, la limitation de débit, le
verrouillage de compte et l'audit ne voient que l'adresse du proxy.

### Les secrets, et ce qui se passe sans eux

`JWT_ACCESS_SECRET` (32 caractères minimum) est **obligatoire**, et différent
entre les deux environnements :

```bash
openssl rand -base64 48
```

Les autres sont **optionnels**, et leur absence dégrade proprement plutôt que
d'empêcher le démarrage :

| Secret | Sans lui |
| --- | --- |
| `STRIPE_SECRET_KEY`, `STRIPE_PRICE_*` | le catalogue reste lisible, l'achat se déclare indisponible |
| `STRIPE_WEBHOOK_SECRET` | l'endpoint de webhook répond 503 — aucun webhook non signé n'est jamais traité |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | l'envoi de notifications est désactivé ; l'enregistrement des jetons d'appareil continue de fonctionner |
| `ANTHROPIC_API_KEY` | le coach IA répond 503 |
| `METRICS_TOKEN` | `/metrics` n'est pas exposé (il est de toute façon refusé par Nginx) |

Vous pouvez donc mettre la recette en ligne **sans aucun secret payant**, et
les ajouter plus tard sans redéployer l'application mobile.

---

## 6. Certificats TLS et vhosts Nginx

### L'ordre compte, et c'est le piège classique

Les vhosts définitifs référencent des certificats. Nginx **refuse de démarrer**
si ces fichiers n'existent pas. Or certbot, en mode webroot, a besoin d'un
Nginx qui tourne pour répondre au défi ACME. On casse la boucle avec un vhost
temporaire en HTTP seul.

```bash
sudo mkdir -p /var/www/certbot
sudo tee /etc/nginx/sites-available/carlys-acme.conf > /dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name api.carlys.example app.carlys.example media.carlys.example
                api-staging.carlys.example app-staging.carlys.example
                media-staging.carlys.example;
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 404; }
}
EOF
sudo ln -sf /etc/nginx/sites-available/carlys-acme.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**Vérification** — depuis l'extérieur, le défi doit être servi en clair :

```bash
echo preuve | sudo tee /var/www/certbot/.well-known/acme-challenge/test > /dev/null
curl http://api.carlys.example/.well-known/acme-challenge/test   # → preuve
sudo rm /var/www/certbot/.well-known/acme-challenge/test
```

### Un certificat par hôte

**Un certificat par nom, pas un certificat multi-noms**, et les vhosts ne
laissent pas le choix : chacun des six blocs HTTPS pointe
`ssl_certificate /etc/letsencrypt/live/<son-nom>/fullchain.pem`. Six
`server_name`, six répertoires, six paires `fullchain.pem` / `privkey.pem`. Un
seul certificat couvrant les six noms (`certbot -d a -d b …`) créerait **un**
répertoire portant le nom du premier `-d`, et les cinq autres vhosts
refuseraient de charger sur un fichier absent.

`certonly` — sans `--nginx` — parce que le greffon Nginx de certbot réécrirait
les vhosts versionnés de ce dépôt. Ici certbot ne touche qu'à
`/etc/letsencrypt/`, la configuration Nginx reste celle du dépôt.

```bash
for h in api app media api-staging app-staging media-staging; do
  sudo certbot certonly --webroot -w /var/www/certbot \
    -d "$h.carlys.example" \
    --agree-tos -m vous@exemple.fr --non-interactive
done
```

**Vérification** — six répertoires, et douze fichiers :

```bash
sudo ls -d /etc/letsencrypt/live/*.carlys.example         # six répertoires
sudo ls   /etc/letsencrypt/live/*.carlys.example/fullchain.pem \
          /etc/letsencrypt/live/*.carlys.example/privkey.pem | wc -l   # 12
```

Une différence entre cette liste et les six `server_name` des vhosts **est** la
panne : `nginx -t` la nommera fichier par fichier à l'activation ci-dessous.

### Le renouvellement doit recharger Nginx

`certbot renew` renouvelle les fichiers ; il ne dit rien à Nginx, qui garde en
mémoire le certificat chargé au démarrage. Sans le crochet ci-dessous, tout se
passe bien pendant quatre-vingt-dix jours, puis les six hôtes servent un
certificat expiré — alors que le nouveau est sur le disque. Le crochet est
global (`renewal-hooks/deploy/`) : il vaut pour les six certificats, et pour
tout certificat ajouté plus tard.

```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
printf '%s\n' '#!/bin/sh' 'systemctl reload nginx' \
  | sudo tee /etc/letsencrypt/renewal-hooks/deploy/recharger-nginx.sh > /dev/null
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/recharger-nginx.sh
```

Il ne se déclenche qu'après un renouvellement **réel** — c'est pourquoi
`certbot renew --dry-run` (étape 10) ne l'exécute pas.

### L'attrape-tout : ce que reçoit un nom qu'on ne sert pas

Le vhost par défaut de Nginx vient d'être retiré, et aucun des six vhosts ne
porte `default_server`. En l'état, Nginx désignerait comme défaut le **premier
bloc rencontré** pour chaque port : `sites-enabled/*` étant inclus par ordre
alphabétique, ce serait le premier bloc 443 de `carlys-production.conf`,
c'est-à-dire l'**API de production**. Une requête sur le domaine nu, sur `www`,
sur l'IP brute ou sur un sous-domaine oublié y atterrirait, avec le certificat
d'`api.carlys.example` — donc un avertissement de sécurité dans le navigateur,
et une porte ouverte là où on n'en voulait pas.

Le vhost attrape-tout reprend cette place et ferme la connexion. Il ne
référence aucun certificat Let's Encrypt : celui qu'il présente est
auto-signé, et c'est correct — il n'existe aucun certificat valide pour un nom
qu'on n'héberge pas.

```bash
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -subj '/CN=hote-inconnu' \
  -keyout /etc/nginx/ssl/attrape-tout.key \
  -out    /etc/nginx/ssl/attrape-tout.crt
sudo chmod 600 /etc/nginx/ssl/attrape-tout.key

sudo cp /srv/carlys/repo/infrastructure/nginx/carlys-attrape-tout.conf.example \
        /etc/nginx/sites-available/carlys-attrape-tout.conf
sudo ln -sf /etc/nginx/sites-available/carlys-attrape-tout.conf /etc/nginx/sites-enabled/
```

Aucun domaine à substituer : ce fichier ne nomme aucun hôte.

**Ne rechargez pas encore.** Le vhost temporaire de l'ACME porte lui aussi
`listen 80 default_server` : les deux ensemble feraient échouer `nginx -t` sur
`a duplicate default server for 0.0.0.0:80`. Le retrait du temporaire et le
rechargement se font en une seule fois, juste en dessous.

### Activer les vhosts définitifs

```bash
cd /srv/carlys/repo
DOMAINE=carlys.example          # ← la SEULE ligne à adapter

sudo cp infrastructure/nginx/snippets/carlys-proxy.conf /etc/nginx/snippets/

for env in staging production; do
  sed "s/carlys\.example/$DOMAINE/g" "infrastructure/nginx/carlys-$env.conf.example" \
    | sudo tee "/etc/nginx/sites-available/carlys-$env.conf" > /dev/null
  sudo ln -sf "/etc/nginx/sites-available/carlys-$env.conf" /etc/nginx/sites-enabled/
done
```

`carlys.example` est le seul motif à remplacer : les trois sous-domaines et les
chemins de certificats en découlent.

Retirez le vhost temporaire **avant de recharger**, puis rechargez une seule
fois. L'ordre n'est pas cosmétique : les vhosts définitifs déclarent eux aussi
un bloc `listen 80`, et laisser les deux jeux actifs ferait ignorer par Nginx
les `server_name` en double (`conflicting server name … ignored`) — le défi
ACME pourrait alors tomber sur le mauvais bloc. Les vhosts définitifs servent
eux-mêmes `/.well-known/acme-challenge/`, le renouvellement continuera donc de
fonctionner sans le fichier temporaire.

```bash
sudo rm /etc/nginx/sites-enabled/carlys-acme.conf
sudo nginx -t && sudo systemctl reload nginx
```

**Vérification** — `nginx -t` doit dire `test is successful`. À ce stade les
six noms répondent en HTTPS, mais avec des erreurs 502 : rien ne tourne encore
derrière. C'est normal.

```bash
curl -sI https://api-staging.carlys.example/health/live | head -1   # 502 attendu

# L'attrape-tout fait son travail : un nom inconnu n'atteint RIEN.
#
# `--resolve` et pas une résolution DNS : le §1 ne fait poser que les SIX
# sous-domaines, et le domaine nu n'en fait délibérément pas partie. Sans
# `--resolve`, curl sortirait donc en 6 (« Could not resolve host ») — un code
# qui ne dit rien de l'attrape-tout, et qu'on prendrait à tort pour sa panne.
# On force ici curl à joindre le serveur en présentant le nom inconnu, ce qui
# est exactement ce que fait un visiteur venu d'un nom pointé chez vous à votre
# insu, ou d'un scanner qui balaie l'IP.
curl -sk --resolve carlys.example:443:203.0.113.10 \
  https://carlys.example/ ; echo "code curl = $?"   # 52 ou 92 : connexion fermée
# …et il présente son certificat auto-signé, pas celui de l'API :
echo | openssl s_client -connect 203.0.113.10:443 -servername carlys.example 2>/dev/null \
  | grep -m1 'subject='            # → CN = hote-inconnu
```

---

## 7. Premier déploiement de la recette

```bash
sudo /srv/carlys/repo/scripts/server/deploy.sh staging <sha12>
```

Reprenez le `sha12` noté à l'étape 4. `deploy.sh` se connecte au registre, tire
les images, **applique les migrations d'abord** (un échec arrête tout, sans
rien basculer), démarre les services, attend que `/health/ready` réponde 200,
et n'inscrit le SHA dans `DEPLOYED` qu'en cas de succès. Si la santé ne répond
pas, il revient au SHA précédent.

**Vérifications** — les trois doivent passer :

```bash
# 1. L'API est vivante ET joint sa base (c'est ce que /ready ajoute à /live).
curl -fsS https://api-staging.carlys.example/health/ready

# 2. L'application web répond, et ses pages légales sont bien embarquées.
curl -sI https://app-staging.carlys.example/         | head -1   # 200
curl -sI https://app-staging.carlys.example/privacy  | head -1   # 200

# 3. La recette n'est pas indexable.
curl -s https://app-staging.carlys.example/robots.txt            # Disallow: /

# 4. Le SHA déployé est bien celui attendu.
cat /srv/carlys/staging/DEPLOYED
```

Un `502` persistant sur l'API : `docker compose logs api` dans le projet
`carlys_staging`. Le message de refus de démarrage nomme la variable fautive.

### La boîte aux lettres de la recette

Les e-mails de recette ne partent nulle part : ils atterrissent dans Mailpit.
Il n'est proxifié par **aucun** vhost, et c'est délibéré — il affiche en clair
tous les liens de vérification et de réinitialisation. Pour le consulter,
depuis votre poste :

```bash
ssh -L 8025:127.0.0.1:8025 utilisateur@203.0.113.10
# puis http://localhost:8025 dans le navigateur local
```

---

## 8. Les builds mobiles

L'application mobile n'est pas déployée par le serveur : elle est **compilée
puis déposée sur les magasins**. Ce qui la relie au serveur, ce sont trois
`--dart-define`.

`android/` et `ios/` ne sont pas versionnés — il faut les engendrer une fois :

```bash
cd apps/mobile
../../scripts/bootstrap_mobile.sh
flutter pub get
```

### Les trois variables, et le filet qui rattrape leur oubli

| `--dart-define` | Recette | Production |
| --- | --- | --- |
| `CARLYS_FLAVOR` | `staging` | `production` |
| `CARLYS_API_BASE_URL` | `https://api-staging.carlys.example` | `https://api.carlys.example` |
| `CARLYS_PUBLIC_WEB_BASE_URL` | `https://app-staging.carlys.example` | `https://app.carlys.example` |

Les flavors acceptés sont exactement `development`, `staging`, `production` et
`demo`. Une valeur inconnue **ne casse pas le build** : elle retombe
silencieusement sur `development`. Écrivez-les correctement.

`CARLYS_API_BASE_URL` s'écrit **sans** le préfixe `/api/v1`, que l'application
ajoute elle-même.

**Le filet, et sa limite.** Un build `staging` ou `production` qui oublie
`CARLYS_PUBLIC_WEB_BASE_URL` embarquerait deux liens légaux morts vers
`localhost:3001` — précisément les liens qu'un examinateur de magasin ouvre.
L'application refuse donc de démarrer dans ce cas. Mais attention : ce contrôle
a lieu **au lancement, pas à la compilation**. Le build réussit, l'`.aab` ou
l'`.ipa` se produit normalement, et c'est la première ouverture qui échoue.
**Lancez toujours l'artefact une fois avant de le déposer.**

### Recette — TestFlight et piste interne

```bash
# Android → Galaxy Store, ou piste interne Play
flutter build appbundle --release \
  --dart-define=CARLYS_FLAVOR=staging \
  --dart-define=CARLYS_API_BASE_URL=https://api-staging.carlys.example \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://app-staging.carlys.example
# → build/app/outputs/bundle/release/app-release.aab

# iOS → TestFlight. macOS OBLIGATOIRE, avec Xcode et un compte Apple Developer.
flutter build ipa --release \
  --dart-define=CARLYS_FLAVOR=staging \
  --dart-define=CARLYS_API_BASE_URL=https://api-staging.carlys.example \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://app-staging.carlys.example
# → build/ios/ipa/*.ipa, à téléverser avec Transporter ou `xcrun altool`
```

### Production — App Store et Play Store

Les mêmes commandes, avec les domaines nus et `CARLYS_FLAVOR=production` :

```bash
flutter build appbundle --release \
  --dart-define=CARLYS_FLAVOR=production \
  --dart-define=CARLYS_API_BASE_URL=https://api.carlys.example \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://app.carlys.example

flutter build ipa --release \
  --dart-define=CARLYS_FLAVOR=production \
  --dart-define=CARLYS_API_BASE_URL=https://api.carlys.example \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://app.carlys.example
```

### Notifications push

Les quatre valeurs Firebase viennent **ensemble ou pas du tout**. Copiez
`apps/mobile/config/firebase.example.json` vers `config/firebase.json` (ignoré
par git) avec les valeurs de votre `google-services.json`, puis ajoutez à
n'importe laquelle des commandes ci-dessus :

```bash
  --dart-define-from-file=config/firebase.json
```

Sans elles, le push est simplement inactif ; le reste de l'application vit
normalement.

### Ce qui n'est pas automatisable

- **iOS exige un macOS.** Ni ce serveur ni la CI Linux ne peuvent produire un
  `.ipa`. C'est une contrainte d'Apple, pas un manque du dépôt.
- **La signature** (keystore Android, certificats et profils Apple) et le
  dépôt sur les magasins restent manuels, comme la création des comptes
  Apple Developer, Google Play Console et Samsung Seller.
- La politique de confidentialité que réclameront les magasins est
  `https://app.carlys.example/privacy` — servie par l'application web, donc
  **l'étape 9 doit être faite avant toute soumission en production**.

---

## 9. Passer en production

La production n'est pas un `deploy.sh` de plus. Elle exige trois choses de
plus, et la première est un vrai travail de rédaction.

### 9.1 Les textes légaux — la garde qu'on ne contourne pas

`docs/legal/privacy.md` et `docs/legal/terms.md` portent des marqueurs
`[À COMPLÉTER : …]` : raison sociale, adresse de contact, pays d'hébergement,
délais de conservation, juridiction. **Tant qu'il en reste un, l'image admin de
production refuse de se construire.**

Comptez-les plutôt que de me croire :

```bash
grep -oP '\[À COMPLÉTER\s*:[^\]]*\]' docs/legal/*.md | sort -u
```

Il n'y a pas de contournement : `--build-arg LEGAL_PLACEHOLDERS=allow` ne
produit que des images de **recette**. Ce n'est pas une chicane administrative
— c'est cette page que les magasins d'applications ouvrent avant d'accepter une
soumission, et un texte inachevé fait refuser la soumission.

### 9.2 Les secrets de production

Contrairement à la recette, la production a besoin des vraies valeurs :

- **Stripe** : `STRIPE_SECRET_KEY` (clé *live*, pas *test*),
  `STRIPE_PRICE_MONTHLY`, `STRIPE_PRICE_YEARLY`, et
  `STRIPE_WEBHOOK_SECRET` obtenu en déclarant l'endpoint
  `https://api.carlys.example/api/v1/webhooks/stripe` dans le tableau de bord
  Stripe (RevenueCat, si vous l'utilisez, pointe vers
  `/api/v1/webhooks/revenuecat`). Les
  prix affichés (`SUBSCRIPTION_*_CENTS`) doivent refléter les prix Stripe :
  c'est Stripe qui encaisse, l'API ne fait qu'afficher.
- **Firebase** : `FIREBASE_SERVICE_ACCOUNT_JSON`, le JSON complet du compte de
  service (console Firebase → Paramètres → Comptes de service).
- **SMTP** : un vrai relais. Mailpit n'existe pas en production ; un
  `SMTP_HOST` qui ne route nulle part rendrait la vérification d'adresse et la
  réinitialisation de mot de passe silencieusement inopérantes.

### 9.3 Construire l'image de production, puis basculer

L'image admin de production est produite par un workflow **déclenché à la
main** : Actions → `images-publish-prod` → *Run workflow* → renseignez le SHA
affiché par `/srv/carlys/staging/DEPLOYED`.

Il vérifie que les images d'API de ce SHA existent déjà — la production
redéploie **les octets éprouvés en recette**, elle ne reconstruit rien —, puis
construit l'admin garde armée et publie
`ghcr.io/mimiflo/carlys-admin:sha-<sha12>-prod`.

Puis, sur le serveur :

```bash
sudo /srv/carlys/repo/scripts/server/promote.sh
```

`promote.sh` relit le SHA de la recette, vérifie la présence du tag `-prod`
dans le registre (s'il manque, il vous dira que les textes légaux bloquent, et
c'est normal), demande confirmation, puis appelle
`deploy.sh production <sha12>`.

**Vérifications :**

```bash
curl -fsS https://api.carlys.example/health/ready
curl -sI  https://app.carlys.example/privacy | head -1   # 200
cat /srv/carlys/production/DEPLOYED
```

Ouvrez `https://app.carlys.example/privacy` dans un navigateur et **lisez-la** :
aucun `[À COMPLÉTER]` ne doit y apparaître.

---

## 10. Ensuite : exploitation courante

### Déployer une nouvelle version

1. Poussez. `images-publish` publie les trois images du nouveau SHA.
2. **Mettez à jour le clone du serveur.** C'est la première chose à faire, et
   la plus facile à oublier :

   ```bash
   sudo git -C /srv/carlys/repo pull --ff-only
   ```

3. `sudo /srv/carlys/repo/scripts/server/deploy.sh staging <nouveau-sha12>`
4. Éprouvez la recette.
5. Lancez `images-publish-prod` sur ce SHA, puis `promote.sh`.

**Pourquoi l'étape 2 n'est pas une formalité.** Ce qui est déployé par SHA, ce
sont les **images**, et elles viennent du registre. Tout le reste vient du
clone `/srv/carlys/repo`, qui ne bouge que si on l'y invite :

| Ce que lit le serveur | D'où ça vient | Ce que ça donne sans `git pull` |
| --- | --- | --- |
| `infrastructure/server/compose.yml` | le clone | les images du nouveau SHA démarrent sous l'ancienne définition de services : variable, volume, port ou service ajouté depuis, absent |
| `scripts/server/deploy.sh`, `promote.sh`, `backup.sh` | le clone | on exploite avec les scripts d'il y a plusieurs semaines |
| `infrastructure/server/env/*.env.example` | le clone | une variable devenue obligatoire n'apparaît nulle part, et l'API refuse de démarrer sans dire d'où sort le nom |
| `infrastructure/nginx/*.conf.example` | le clone | un vhost corrigé n'est pas recopié (voir plus bas) |

Le symptôme est trompeur : `deploy.sh` tire bien les bonnes images, la
commande réussit à moitié, et la panne ressemble à un bug applicatif. Elle est
seulement due à un fichier compose vieux de plusieurs semaines.

**Les vhosts, eux, ne se rechargent pas tout seuls.** `git pull` met à jour les
`*.conf.example` du dépôt, pas les fichiers actifs de `/etc/nginx/`. Si une
version modifie un vhost, il faut rejouer la substitution de l'étape 6
(section « Activer les vhosts définitifs »), puis
`sudo nginx -t && sudo systemctl reload nginx`. Les notes de version le disent
quand c'est le cas ; en son absence, ce `git pull` suffit.

**Toujours par SHA, jamais par tag mouvant.** Le tag `staging` existe pour
qu'on voie d'un coup d'œil ce qui est récent dans l'onglet Packages ; s'en
servir pour déployer ferait diverger la recette et la production sans qu'on
puisse dire quand.

### Sauvegardes

`setup.sh` installe une tâche quotidienne qui appelle `backup.sh` :
`pg_dump` des deux bases dans `/srv/carlys/backups/`, horodaté, rétention
14 jours.

```bash
ls -lh /srv/carlys/backups/ | tail -5
sudo /srv/carlys/repo/scripts/server/backup.sh   # à la demande
```

Une sauvegarde jamais restaurée n'est pas une sauvegarde : testez une
restauration sur la base de recette de temps en temps.

### Renouvellement des certificats

certbot installe son propre minuteur. Vérifiez-le une fois, ainsi que le
crochet de rechargement posé à l'étape 6 — sans lui, les fichiers sont
renouvelés mais Nginx continue de servir les anciens :

```bash
ls -l /etc/letsencrypt/renewal-hooks/deploy/   # recharger-nginx.sh, exécutable
sudo certbot renew --dry-run                   # n'exécute PAS le crochet : un
                                               # essai à blanc ne « déploie » rien
systemctl list-timers | grep certbot
```

### Journaux

```bash
docker compose -p carlys_staging    logs -f --tail=100 api
docker compose -p carlys_production logs -f --tail=100 api
sudo tail -f /var/log/nginx/error.log
```

Les journaux de l'API sont structurés (Pino) et corrélés par `requestId` :
c'est ce champ qu'on suit d'une requête à l'autre.

---

## Où regarder quand ça ne marche pas

| Symptôme | Cause la plus fréquente |
| --- | --- |
| `nginx -t` échoue sur un certificat | l'étape 6 a été faite avant que les DNS résolvent |
| 502 sur tous les hôtes | aucun conteneur ne tourne : le déploiement a échoué ou n'a pas eu lieu |
| 502 sur l'API seule | refus de démarrage sur une variable — `docker compose logs api` la nomme |
| Le back-office s'affiche mais reste vide | image admin construite sans `CARLYS_DOMAIN` (étape 4) |
| Les liens des e-mails pointent en local | `PUBLIC_APP_URL` mal renseignée |
| L'app mobile plante au lancement | `CARLYS_PUBLIC_WEB_BASE_URL` oubliée au build (étape 8) |
| `promote.sh` dit que le tag `-prod` manque | les marqueurs légaux subsistent (étape 9.1) |
| L'IP du client est toujours la même dans l'audit | `TRUST_PROXY_HOPS` ≠ 1 |
| Un service, un volume ou une variable manque après un déploiement pourtant réussi | le clone `/srv/carlys/repo` n'a pas été mis à jour : `deploy.sh` a tiré les bonnes images et les a démarrées sous un `compose.yml` périmé (étape 10) |
| Un hôte inconnu (domaine nu, `www`, IP brute) atteint l'API de production | le vhost attrape-tout n'est pas activé (étape 6) |
| Certificat expiré alors que `certbot renew` dit avoir renouvelé | le crochet de rechargement Nginx manque (étape 6) |

## À lire à côté

- [`infrastructure/deployment/README.md`](../../infrastructure/deployment/README.md) — pourquoi les migrations tournent avant la bascule, et comment l'arbre de production est fabriqué.
- [`infrastructure/nginx/README.md`](../../infrastructure/nginx/README.md) — ce que garantissent les vhosts.
- [`docs/security/reverse-proxy.md`](../security/reverse-proxy.md) — `TRUST_PROXY_HOPS`, TLS, limites de taille.
- [`apps/mobile/README.md`](../../apps/mobile/README.md) — configuration d'exécution de l'application.

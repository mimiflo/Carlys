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
vhosts : aucun des six `server_name` ne les couvre, une visite y tomberait sur
le vhost par défaut de Nginx. Si vous voulez y mettre un site vitrine, c'est un
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
   local.** Cela concerne `PUBLIC_APP_URL`, `S3_PUBLIC_BASE_URL` et
   `CORS_ORIGINS`.

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

Les vhosts attendent un répertoire de certificat **par nom** :

```bash
for h in api app media api-staging app-staging media-staging; do
  sudo certbot certonly --webroot -w /var/www/certbot \
    -d "$h.carlys.example" \
    --agree-tos -m vous@exemple.fr --non-interactive
done
```

**Vérification :**

```bash
sudo ls -d /etc/letsencrypt/live/*.carlys.example   # six répertoires
```

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
2. `sudo /srv/carlys/repo/scripts/server/deploy.sh staging <nouveau-sha12>`
3. Éprouvez la recette.
4. Lancez `images-publish-prod` sur ce SHA, puis `promote.sh`.

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

certbot installe son propre minuteur. Vérifiez-le une fois :

```bash
sudo certbot renew --dry-run
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

## À lire à côté

- [`infrastructure/deployment/README.md`](../../infrastructure/deployment/README.md) — pourquoi les migrations tournent avant la bascule, et comment l'arbre de production est fabriqué.
- [`infrastructure/nginx/README.md`](../../infrastructure/nginx/README.md) — ce que garantissent les vhosts.
- [`docs/security/reverse-proxy.md`](../security/reverse-proxy.md) — `TRUST_PROXY_HOPS`, TLS, limites de taille.
- [`apps/mobile/README.md`](../../apps/mobile/README.md) — configuration d'exécution de l'application.

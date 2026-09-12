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

**Ce serveur ne termine pas le TLS**, et c'est la chose à avoir en tête d'un
bout à l'autre de ce guide :

```
Internet / mobile / navigateur
      │ HTTPS 443
      ▼
gra6.luuc.fr          ← reverse proxy réseau : détient les certificats,
      │ HTTP interne     termine le TLS, ne fait pas partie de ce dépôt
      ▼
172.16.0.158:80       ← ce serveur, Nginx en HTTP SEUL
      ▼
services Docker sur 127.0.0.1
```

Les six noms publics restent en `https://` **pour le client** — c'est gra6 qui
le lui sert. Aucun certificat, aucun certbot, aucun `listen 443` sur cette
machine. En contrepartie, deux exigences pèsent sur gra6 et sur le pare-feu :
l'étape 6 les énonce, et elles ne se supposent pas remplies.

> **Ce que ce guide n'automatise pas, et n'automatisera pas.** L'achat du
> domaine, les enregistrements DNS, **la configuration de gra6** — elle n'est
> dans aucun dépôt et se pose à la main, là-bas —, les comptes Apple / Google
> Play / Samsung, la rédaction des textes légaux, et les vraies valeurs des
> secrets (Stripe, Firebase, Sentry, SMTP). La bascule en production reste un
> **geste humain** : c'est une règle du dépôt, pas une limite technique.

---

## 0. Ce qu'il faut avoir sous la main

- Un serveur Debian 12 ou Ubuntu 22.04+, accès `root` ou `sudo`, joignable sur
  le réseau interne — son adresse est notée `172.16.0.158` dans tout ce guide.
  Il n'a **pas besoin d'adresse publique** : rien venant d'Internet ne le
  frappe directement.
- Un nom de domaine dont vous contrôlez la zone DNS.
- **Le reverse proxy réseau `gra6.luuc.fr`**, déjà en service, et un accès à sa
  configuration — ou quelqu'un qui l'a. C'est lui qui détient les certificats
  des six noms publics, termine le TLS et relaie ici en clair. Trois en-têtes
  qu'il doit poser conditionnent l'adresse du client vue par l'API : §6.
- Un compte GitHub ayant accès au dépôt `mimiflo/Carlys`.
- **Pour l'étape 8 seulement — sur VOTRE POSTE, pas sur le serveur** : un clone
  du dépôt et le SDK Flutter **3.44.9** (la version est épinglée dans
  `apps/mobile/.flutter-version`), plus l'Android SDK et ses licences.
  `setup.sh` n'installe rien de tout cela sur le serveur, et n'a pas à le
  faire. L'installation du poste est décrite dans
  [`docs/development/poste-de-travail.md`](../development/poste-de-travail.md).
  Pour les builds iOS, ajoutez un **macOS** avec Xcode et un compte Apple
  Developer — ou laissez le runner macOS de GitHub les faire, sur demande
  (`docs/deployment/builds-mobiles.md`, §10).

---

## 1. DNS — six enregistrements vers gra6, à poser en premier

Rien d'autre ne peut avancer tant que les noms ne résolvent pas : c'est gra6
qui reçoit les connexions publiques, et il ne peut rien recevoir pour un nom
qu'aucune zone ne lui envoie.

| Type | Nom | Valeur |
| ---- | --- | ------ |
| CNAME | `api` | `gra6.luuc.fr.` |
| CNAME | `app` | `gra6.luuc.fr.` |
| CNAME | `media` | `gra6.luuc.fr.` |
| CNAME | `api-staging` | `gra6.luuc.fr.` |
| CNAME | `app-staging` | `gra6.luuc.fr.` |
| CNAME | `media-staging` | `gra6.luuc.fr.` |

Trois par environnement, et **aucun ne pointe sur `172.16.0.158`** : ce serveur
n'est pas joignable depuis Internet, et n'a pas à l'être.

**`CNAME`, et pas `A`.** Un `A` figerait dans votre zone l'adresse d'une
machine qui ne vous appartient pas : le jour où gra6 change d'adresse, les six
enregistrements deviendraient faux, tous en même temps, et la panne se
présenterait comme une indisponibilité totale sans rien pour la relier à un
changement d'ailleurs. Le `CNAME` délègue cette adresse à la zone de gra6, qui
est celle qui sait. Ces six noms sont des sous-domaines, donc le `CNAME` y est
licite — ce qui ne serait pas le cas sur le domaine nu. Rien à ajouter côté
`AAAA` : ce que gra6 publie en IPv6, le `CNAME` le suit tout seul.

Le domaine nu (`carlys.example`) et `www` ne sont **pas** servis par ces
vhosts : aucun des six `server_name` ne les couvre. Ce qu'ils reçoivent est
décidé par le vhost **attrape-tout** posé à l'étape 6 — une connexion fermée
sans réponse (`444`). Sans lui, Nginx désignerait d'office comme défaut le
premier bloc rencontré, c'est-à-dire l'**API de production** : un `Host`
inconnu relayé par gra6, ou une requête arrivant en direct sur le port 80,
atteindrait la production. Si vous voulez mettre un site vitrine sur le domaine
nu, c'est un vhost de plus — sur gra6, hors de ce guide.

**Vérification** — depuis n'importe quelle machine, une fois la propagation
faite (de quelques minutes à quelques heures) :

```bash
for h in api app media api-staging app-staging media-staging; do
  printf '%-22s %s\n' "$h" "$(dig +short "$h.carlys.example" | paste -sd' ' -)"
done
dig +short gra6.luuc.fr        # l'adresse que les six lignes doivent finir par montrer
```

`dig +short` sur un `CNAME` affiche **d'abord la cible, puis l'adresse
résolue** : chacune des six lignes doit donc commencer par `gra6.luuc.fr.` et
se terminer par l'adresse rendue par la dernière commande. Une ligne vide =
enregistrement absent ou pas encore propagé : **attendez**, ne passez pas à la
suite. Une ligne qui montre `172.16.0.158` = un `A` a été posé au lieu du
`CNAME` : corrigez-le maintenant, il n'y a rien derrière ce port pour un
visiteur d'Internet, et le pare-feu de l'étape 2 le lui refusera de toute
façon.

---

## 2. Préparer le serveur

Sur le serveur, en `root` :

```bash
apt-get update && apt-get install -y git
git clone https://github.com/mimiflo/Carlys.git /srv/carlys/repo
cd /srv/carlys/repo

# L'adresse depuis laquelle le port 80 sera ouvert — celle de gra6, et elle
# seule. Trouvez-la avant de lancer le script. `getent` plutôt que `dig` :
# il est là sur un Debian nu, `dig` demande le paquet dnsutils.
getent hosts gra6.luuc.fr        # → l'adresse, puis le nom

sudo CARLYS_PROXY_CIDR=<adresse de gra6> ./scripts/server/setup.sh
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

`setup.sh` installe Docker et le plugin Compose, Nginx, ufw et cron, ferme
l'entrée sauf 22 (SSH) et 80 **depuis la seule adresse donnée en
`CARLYS_PROXY_CIDR`**, crée l'arborescence `/srv/carlys/`, y dépose les `.env`
à remplir depuis les exemples versionnés, installe la tâche quotidienne de
sauvegarde, et **arme la supervision** — une minuterie systemd qui passe toutes
les deux minutes. **Il est idempotent** : le relancer sur un serveur déjà
configuré ne casse rien et ne réécrit aucun `.env` déjà rempli.

Deux choses qu'il pose et dont on ne se rend compte qu'en leur absence :

- **les amonts Nginx de départ.** Les vhosts du dépôt ne déclarent pas l'amont
  de l'API — elle tourne en plusieurs exemplaires sur des ports que Docker
  attribue, et c'est `carlysctl` qui écrit la liste réelle. Tant que ce fichier
  n'existe pas, `nginx -t` échoue sur *host not found in upstream*. `setup.sh`
  en pose une version à un seul exemplaire **avant** de démarrer Nginx ;
- **la minuterie de supervision.** Elle répare ce qui tombe et ajuste le nombre
  d'exemplaires à la charge. Elle **ne déploie rien** : la mise à jour
  automatique reste commandée par `CARLYS_AUTO_UPDATE`, livré à `non`. Tout est
  dans [orchestration.md](orchestration.md).

**Il n'installe PAS certbot, et il retire la règle 443 si elle traîne d'une
installation antérieure** (`scripts/server/setup.sh`, étapes 1/9 et 4/9). C'est
la conséquence directe de l'architecture : les certificats des six noms vivent
sur gra6. Un certbot posé ici armerait une minuterie de renouvellement pour des
certificats qui n'existent pas, et laisserait croire au prochain exploitant que
le TLS se règle sur ce serveur.

> **Sans `CARLYS_PROXY_CIDR`, le port 80 n'est PAS ouvert** — le script le dit
> à l'écran et le redit dans son récapitulatif final. Ce n'est pas un oubli :
> il refuse d'ouvrir 80 au monde en silence. Le raisonnement est le même que
> pour l'attrape-tout, et l'étape 6 le développe — nos vhosts posent
> `X-Forwarded-Proto: https` **en dur**, ce qui n'est honnête que si le seul
> émetteur possible est un proxy ayant réellement terminé du TLS. Une machine
> injoignable vaut mieux qu'une machine qui ment. Pour rattraper sans rejouer
> le script : `ufw allow from <adresse de gra6> to any port 80 proto tcp`.

**Vérification :**

```bash
echo $?                                      # 0 : aucun service en défaut
docker --version && docker compose version   # les deux répondent
docker info > /dev/null && echo 'démon ok'   # le CLI peut répondre sans lui
systemctl is-active docker nginx cron        # trois fois « active »
ufw status | head -8                         # 22, et 80 DEPUIS gra6 ; pas de 443
ls -la /srv/carlys/                          # staging/ production/ backups/
```

La ligne du 80 doit nommer une source. `80/tcp ALLOW Anywhere` n'est **pas**
l'état attendu : c'est la règle large d'une installation antérieure, à effacer
(`ufw delete allow 80/tcp`) avant de reposer celle de gra6.

**Le code de sortie compte autant que l'affichage.** Si un service refuse de
démarrer, `setup.sh` va quand même au bout des sept étapes, affiche tout son
récapitulatif — puis sort en **1** en nommant le service en défaut, tout à la
fin. Sept `✓` à l'écran ne veulent donc pas dire que tout va bien : c'est
`echo $?` qui tranche. `docker --version` en particulier répond très bien
alors que le **démon** est à l'arrêt ; sans `docker info`, la panne ne se
révélerait qu'à l'étape 3, sur un `docker login` qui rend « Cannot connect to
the Docker daemon » sans que rien ne la relie à ici.

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

Poussez ensuite sur **`development`**
— ce sont les deux seules branches que `images-publish` écoute. Une poussée
ailleurs ne déclenche **rien** : pas d'exécution, donc pas de message d'erreur,
et rien à regarder pour la vérification ci-dessous. Vous pouvez aussi lancer le
workflow à la main depuis l'onglet Actions. Il publie trois images :

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

**Puis rafraîchissez le clone du serveur**, avant de remplir quoi que ce soit :

```bash
sudo git -C /srv/carlys/repo pull --ff-only
```

Le commit que vous venez de pousser peut toucher `infrastructure/server/`,
`scripts/server/` ou les `*.env.example` — c'est le cas d'une bonne part des
correctifs. Sans ce `pull`, vous rempliriez à l'étape 5 un `.env` issu d'un
modèle périmé, et l'étape 7 démarrerait les bonnes images sous une définition
de services qui ne les connaît pas. L'étape 10 explique pourquoi ce geste
revient à chaque déploiement.

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

4. **Un `$` dans une valeur ouvre une substitution Compose.** C'est la règle
   qui fait perdre une soirée, parce qu'elle échoue parfois *sans rien dire* :
   `MDP=mot$de$passe` arrive dans le conteneur comme `mot`, et si le nom qui
   suit le `$` existe côté hôte la substitution **réussit en silence** —
   `mot$HOME/x` devient `mot/root/x`. Il faut **doubler chaque `$` en `$$`**.
   Les recettes de ce guide (`openssl rand …`) n'en produisent jamais ; un mot
   de passe fourni par un tiers, une empreinte `$2b$…` ou `$argon2id$…`, et
   surtout `FIREBASE_SERVICE_ACCOUNT_JSON`, si.

En revanche, ce qui **reste interne au réseau Compose** n'est pas concerné :
`S3_ENDPOINT=http://minio:9000` passe parfaitement dans les deux
environnements. C'est une adresse de conteneur, pas une adresse publique.

`SMTP_HOST=mailpit`, en revanche, ne vaut **qu'en recette** : le service
Mailpit est déclaré `profiles: ['staging']` dans `compose.yml`, et la
production ne pose aucun profil — le conteneur n'y existe donc pas. Voir
« Les e-mails de production » plus bas.

### Une seule ligne commande les URL : `DOMAIN`

Les deux modèles versionnés dérivent `PUBLIC_APP_URL`, `CORS_ORIGINS`,
`S3_PUBLIC_BASE_URL` et `EMAIL_FROM` d'**une seule variable**, en tête de
fichier :

```bash
DOMAIN=CHANGE_MOI_exemple.fr
```

N'écrivez donc pas les URL en dur : changez cette ligne, et les quatre autres
suivent. Le tableau ci-dessous dit ce que le fichier doit **produire**, pour
que vous puissiez le vérifier — pas ce qu'il faut recopier.

| Variable | Recette | Production |
| --- | --- | --- |
| `PUBLIC_APP_URL` | `https://app-staging.carlys.example` | `https://app.carlys.example` |
| `CORS_ORIGINS` | `https://app-staging.carlys.example` | `https://app.carlys.example` |
| `S3_PUBLIC_BASE_URL` | `https://media-staging.carlys.example/carlys-media` | `https://media.carlys.example/carlys-media` |
| `TRUST_PROXY_HOPS` | `2` | `2` |

`PUBLIC_APP_URL` désigne l'**application web**, jamais l'API : c'est la base
des liens envoyés par e-mail et des retours Stripe.

**Les URL publiques restent en `https://`, et ce n'est pas une inattention.**
Le saut gra6 → ce serveur est en clair, mais il est *interne* : ce que
décrivent ces quatre variables, c'est ce que voit le client, et le client a
bien parlé HTTPS à gra6. Un `http://` glissé ici serait à la fois faux et
refusé au démarrage (règle 3 ci-dessus).

**`TRUST_PROXY_HOPS=2`, parce qu'il y a DEUX proxys.** La chaîne est
`client → gra6 → ce Nginx → Express` : gra6 écrit dans `X-Forwarded-For`
l'adresse du client, le Nginx d'ici y ajoute celle de gra6 — la liste compte
donc deux entrées. Express (`app.set('trust proxy', n)`,
`apps/api/src/app/configure-app.ts`) remonte cette liste par la droite et saute
`n` entrées. Mesuré sur la chaîne montée pour de vrai — trois conteneurs, un
client honnête, gra6 posant l'en-tête :

| `TRUST_PROXY_HOPS` | `req.ip` vaut |
| --- | --- |
| `1` | l'adresse de **gra6** — tout Internet partage un seul seau de limitation de débit |
| `2` | l'adresse du **client** ✓ |
| `3` | identique à `2` : la liste est saturée, il n'y a rien de plus à sauter |

La valeur `1` était juste tant qu'un seul Nginx se tenait devant l'API. Avec
`1` aujourd'hui, la limitation de débit, le verrouillage de compte et l'audit
ne voient plus qu'une adresse, celle de gra6 — et la panne est silencieuse :
tout continue de fonctionner, seules les protections deviennent aveugles.

> **Ce compteur ne protège pas contre un client qui forge son adresse ; c'est
> gra6 qui le fait.** Un compteur de sauts numérique ne retire des entrées que
> **par la droite** : tout ce qu'un client *préfixe* survit, quel que soit le
> nombre de sauts. La garde est l'écrasement de `X-Forwarded-For` par gra6,
> exigé et démontré au §6. Monter `TRUST_PROXY_HOPS` ne la remplacerait pas.

**Vérification, une fois les deux fichiers remplis** — aucune valeur d'exemple
ne doit subsister :

```bash
grep -n 'CHANGE_MOI' /srv/carlys/staging/.env /srv/carlys/production/.env
# → aucune ligne : les deux fichiers sont complets.
```

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

> **« Optionnel » veut dire ABSENT, pas vide.** Chacun de ces secrets est
> déclaré `z.string().min(n).optional()` dans `env.schema.ts` : l'absence de
> clé passe, mais `METRICS_TOKEN=` — la clé présente et vide — échoue sur
> `min(16)` et **empêche l'API de démarrer**. Le réflexe naturel, laisser la
> ligne en place en vidant sa valeur, est donc exactement le geste à ne pas
> faire : **commentez la ligne ou supprimez-la**.

Vous pouvez donc mettre la recette en ligne **sans aucun secret payant**, et
les ajouter plus tard sans redéployer l'application mobile.

### Les e-mails de production

En recette, tout part dans Mailpit et rien ne sort de la machine. En
production, il faut un vrai relais — et le schéma impose une contrainte qu'il
vaut mieux découvrir maintenant que le jour de la bascule :

> **Le schéma ne prévoit NI identifiant NI mot de passe SMTP.**
> `env.schema.ts` ne déclare que `SMTP_HOST`, `SMTP_PORT` et `EMAIL_FROM` : il
> n'existe pas de `SMTP_USER`, pas de `SMTP_PASSWORD`. Le relais doit donc
> accepter ce serveur **sans authentification** — relais autorisé par adresse
> IP, ou passerelle locale (Postfix en `relayhost`). Un fournisseur qui exige
> `AUTH` sur le 587 ne fonctionnera pas en l'état.

`EMAIL_FROM` doit par ailleurs appartenir au domaine, avec SPF et DKIM en
place : sans quoi les messages de vérification d'adresse partent en
indésirables, et l'inscription paraît cassée sans qu'aucun journal ne le dise.

---

## 6. Le reverse proxy réseau, et les vhosts d'ici

### La chaîne : qui termine quoi

```
client ──HTTPS 443──> gra6.luuc.fr ──HTTP──> 172.16.0.158:80 ──> 127.0.0.1:31xx
                       ▲ certificats          ▲ Nginx d'ici       ▲ conteneurs
                         + terminaison TLS      HTTP SEUL
```

Sur gra6, qui n'est **pas** cette machine et ne fait pas partie de ce dépôt :
les certificats des six noms publics, leur renouvellement, la terminaison TLS,
HTTP/2 (qui se négocie dans la poignée de main TLS, donc là-bas), et le routage
vers `172.16.0.158:80` en HTTP interne.

Sur ce serveur, ce qui **n'existe plus** — et qu'il ne faut donc pas chercher
dans les vhosts versionnés, où c'est absent volontairement :

- aucun certificat public `*.carlys.example`, aucun `/etc/letsencrypt/` ;
- aucun certbot, ni paquet, ni greffon, ni minuterie, ni crochet de
  rechargement ;
- aucun `listen 443`, aucune redirection HTTP → HTTPS locale ;
- aucun `/.well-known/acme-challenge/`, aucun vhost ACME temporaire.

Ce qui **ne change pas** : les six `server_name`, à l'identique ; le routage
vers l'API, l'admin et MinIO, à l'identique ; les protections qui restent
applicables derrière un proxy (HSTS, en-têtes, refus de `/metrics`, fermeture
de la racine du bucket, limites de taille de corps) ; et les URL publiques, qui
restent en `https://`. HTTPS existe toujours pour le client — il est seulement
terminé un cran plus haut.

### Ce qu'on EXIGE de gra6 : trois en-têtes, à vérifier, pas à supposer

Ces trois lignes sont à poser dans le vhost de gra6 qui sert les six noms
Carlys. **Traitez-les comme un prérequis dont vous ne supposez pas qu'il est
rempli** : la suite de cette section les éprouve pour de bon.

```nginx
proxy_pass         http://172.16.0.158:80;
proxy_set_header   Host              $host;          # conserver le Host original
proxy_set_header   X-Forwarded-For   $remote_addr;   # ÉCRASER, jamais ajouter
proxy_set_header   X-Forwarded-Proto https;
```

**`Host` conservé** parce que c'est lui, et lui seul, qui choisit le service ici :
les six vhosts se distinguent par `server_name`. Un `Host` réécrit — la valeur
par défaut de certains proxys est l'adresse de l'amont — n'est reconnu par
aucun des six, tombe sur l'attrape-tout, et rend une connexion fermée sur
**tous** les noms à la fois. Le nom public sert par ailleurs à fabriquer les
liens des e-mails.

**`X-Forwarded-For` ÉCRASÉ** — c'est le point qui décide de la sécurité de
toute la chaîne, et il ne se déduit pas, il se mesure. Chaîne montée pour de
vrai en trois conteneurs (client → nginx « gra6 » → nginx « carlys » →
Express 5.2.1 avec `app.set('trust proxy', n)`, soit exactement ce que fait
`apps/api/src/app/configure-app.ts`), avec un client qui **forge** lui-même
`X-Forwarded-For: 1.2.3.4` :

| Ce que gra6 pose | Ce que l'API voit | Ce qu'elle retient |
| --- | --- | --- |
| `$proxy_add_x_forwarded_for` | `1.2.3.4, <client>, <gra6>` | `1.2.3.4` — **FORGÉ** |
| `$http_x_forwarded_for` | `1.2.3.4, <gra6>` | `1.2.3.4` — **FORGÉ** |
| `$remote_addr` | `<client>, <gra6>` | `<client>` — **SÛR** |

(Revérifié avec un client envoyant `9.9.9.9, 8.8.8.8` : ignoré de la même
façon.) **La raison** : un compteur de sauts numérique ne retire des entrées
que **par la droite**. Tout ce qu'un client *préfixe* survit, quel que soit le
nombre de sauts — augmenter `TRUST_PROXY_HOPS` ne fait qu'en sauter davantage
par la droite, jamais nettoyer la gauche. **La protection ne vient donc pas du
nombre de sauts, elle vient de gra6 qui écrase l'en-tête.**

Si gra6 ajoute au lieu d'écraser, n'importe quel client se fait passer pour
n'importe quelle adresse : limitation de débit contournée et journal
d'audit empoisonné. Le risque est concret et daté du
code d'aujourd'hui — `request.ip` est lu à **six endroits** de `apps/api/src`
(`admin-users.controller.ts` deux fois, `admin-community.controller.ts`,
`catalog-actor.ts`, `media.controller.ts`, `authenticated-request.ts` : toutes
des écritures d'audit), plus le `ThrottlerGuard` posé en `APP_GUARD` global
dans `app.module.ts`.

**`X-Forwarded-Proto: https`** pour que le client soit décrit tel qu'il est.
Le Nginx d'ici le repose de toute façon **en dur** (`snippets/carlys-proxy.conf`) :
ni `$scheme`, qui vaudrait `http` puisque gra6 nous parle en clair, ni
`$http_x_forwarded_proto`, dont on ne suppose rien. Mesuré sur la même chaîne :
l'API voit alors `req.protocol = 'https'` et `req.secure = true` alors que tout
le trajet interne est en clair — c'est ce qui garantit qu'une URL publique ne
se fabriquera jamais en `http://`.

> **Corollaire de pare-feu, à traiter comme une exigence et pas comme une
> option** : `172.16.0.158:80` ne doit être joignable **que depuis gra6**
> (`CARLYS_PROXY_CIDR`, étape 2). Sinon n'importe qui obtient de l'API ce
> `req.secure = true` mensonger, et surtout s'adresse à elle sans être passé
> par l'écrasement de `X-Forwarded-For` ci-dessus.
>
> Pour situer le risque à sa juste place : aujourd'hui, **aucun fichier de
> `apps/api/src` ne lit `req.protocol` ni `req.secure`** (vérifié par
> recherche). `X-Forwarded-Proto` est une garantie d'avenir ; c'est
> `X-Forwarded-For` qui porte tout le risque du jour.

### Éprouver la chaîne AVANT d'y mettre Carlys

Rien de ce qui précède ne se vérifie en le lisant. On pose donc un **miroir
temporaire** — un vhost qui répond n'importe quel `Host` et récite ce qu'il a
reçu — et on l'interroge depuis l'extérieur, à travers gra6. C'est le seul
moment du guide où l'on voit la chaîne complète sans qu'un conteneur puisse
brouiller le diagnostic.

```bash
sudo tee /etc/nginx/sites-available/carlys-miroir.conf > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    default_type text/plain;
    location = /miroir {
        return 200 "Host=$http_host\nXFF=$http_x_forwarded_for\nProto=$http_x_forwarded_proto\nvu-d-ici=$remote_addr\n";
    }
    location / { return 404; }
}
EOF
sudo ln -sf /etc/nginx/sites-available/carlys-miroir.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

**Test 1 — les six noms résolvent vers gra6.** C'est la vérification du §1 ;
rejouez-la si vous avez sauté des étapes. Tant qu'un nom ne résout pas, les
tests suivants échoueront pour une raison qui n'a rien à voir avec gra6.

**Test 2 — gra6 joint bien `172.16.0.158:80`.** Depuis votre poste, sur chacun
des six noms :

```bash
for h in api app media api-staging app-staging media-staging; do
  printf '%-22s %s\n' "$h" "$(curl -s -o /dev/null -w '%{http_code}' \
    "https://$h.carlys.example/miroir")"
done
```

Six fois `200`. Un `502` ici est celui de **gra6**, pas le nôtre, et il ne veut
dire qu'une chose : gra6 n'a pas pu joindre le port 80. Le discriminateur, sur
le serveur Carlys :

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

Si la requête n'y figure pas, elle n'est jamais arrivée : pare-feu
(`CARLYS_PROXY_CIDR` absent ou faux — étape 2), Nginx arrêté, ou mauvaise
adresse dans le `proxy_pass` de gra6. Si elle y figure, le problème est en aval
et ce n'est plus un problème de chaîne.

**Test 3 — le `Host` arrive intact.** Le corps de la réponse le dit :

```bash
curl -s https://api-staging.carlys.example/miroir
```

```
Host=api-staging.carlys.example      ← le nom PUBLIC, pas 172.16.0.158
XFF=<votre adresse publique>
Proto=https
vu-d-ici=<adresse de gra6>
```

`Host=172.16.0.158` ou `Host=<autre chose>` : gra6 réécrit le `Host`. Aucun des
six vhosts ne le reconnaîtra, tout tombera sur l'attrape-tout, et le symptôme
sera « les six noms sont morts » alors que le routage d'ici est bon. Notez au
passage `vu-d-ici` : c'est l'adresse de gra6, celle qui doit figurer dans la
règle `ufw` de l'étape 2.

**Test 4 — `X-Forwarded-For` porte l'adresse du client, et résiste à une
forgerie.** Deux appels depuis la même machine :

```bash
curl -s https://api-staging.carlys.example/miroir | grep '^XFF='
curl -s -H 'X-Forwarded-For: 1.2.3.4' \
     https://api-staging.carlys.example/miroir | grep '^XFF='
```

Le premier appel doit rendre votre adresse publique. Le second, celui qui
compte, se lit ainsi :

| Ce que rend le second appel | Verdict |
| --- | --- |
| `XFF=<votre adresse>` | gra6 **écrase** (`$remote_addr`) ✓ — c'est le seul état acceptable |
| `XFF=1.2.3.4` | gra6 relaie l'en-tête du client (`$http_x_forwarded_for`) ✗ |
| `XFF=1.2.3.4, <votre adresse>` | gra6 **ajoute** (`$proxy_add_x_forwarded_for`) ✗ |
| `XFF=` (vide, aux deux appels) | gra6 ne pose pas l'en-tête du tout : l'API ne verra jamais que l'adresse de gra6, quelle que soit la valeur de `TRUST_PROXY_HOPS` |

Les trois dernières lignes sont la panne décrite plus haut ; les deux du milieu
sont la plus grave, celle qui laisse un inconnu choisir l'adresse qu'on lui
attribuera. À ce stade elle ne coûte rien à corriger, plus tard elle se paiera
en audit empoisonné. **Ne passez pas à la suite tant que le second appel ne rend
pas votre propre adresse.** Ce que le miroir affiche est ce que gra6 a écrit ;
le Nginx d'ici y ajoutera ensuite l'adresse de gra6, et c'est ce second saut que
compte `TRUST_PROXY_HOPS=2` (§5).

Le miroir a fini son travail — il sera retiré juste en dessous, en même temps
que le rechargement qui installe les vhosts définitifs.

### L'attrape-tout : ce que reçoit un `Host` qu'on ne sert pas

Le vhost par défaut de Nginx vient d'être retiré, et aucun des six vhosts
Carlys ne porte `default_server`. En l'état, Nginx désignerait comme défaut le
**premier bloc rencontré** pour le port 80 : `sites-enabled/*` étant inclus par
ordre alphabétique, ce serait le premier bloc de `carlys-production.conf`,
c'est-à-dire l'**API de production**.

Deux requêtes doivent tomber sur l'attrape-tout plutôt que là : un `Host`
inconnu relayé par gra6 (domaine nu, `www`, sous-domaine oublié), et une
requête arrivant **en direct** sur `172.16.0.158:80` sans être passée par gra6
— donc sans l'écrasement de `X-Forwarded-For`, tout en se voyant quand même
poser `X-Forwarded-Proto: https` par nos vhosts.

```bash
sudo cp /srv/carlys/repo/infrastructure/nginx/carlys-attrape-tout.conf.example \
        /etc/nginx/sites-available/carlys-attrape-tout.conf
sudo ln -sf /etc/nginx/sites-available/carlys-attrape-tout.conf /etc/nginx/sites-enabled/
```

Aucun domaine à substituer : ce fichier ne nomme aucun hôte, c'est sa raison
d'être. **Rien à préparer non plus** : il ne présente plus de certificat
auto-signé, puisqu'il ne termine plus de TLS — il ferme la connexion sans rien
renvoyer (`return 444`). Si `/etc/nginx/ssl/attrape-tout.{crt,key}` traîne
d'une installation antérieure, plus aucun fichier ne les référence et ils
peuvent être supprimés.

> **Sa portée a une limite, et il vaut mieux la connaître.** Un client qui
> frappe `172.16.0.158:80` en direct **en écrivant `Host: api.carlys.example`**
> passe par le vhost de l'API, pas par ici. La garde principale contre l'accès
> direct est le **pare-feu** ; l'attrape-tout n'en est que la seconde couche,
> celle qui reste debout quand la première est mal posée.

**Ne rechargez pas encore.** Le miroir porte lui aussi `listen 80
default_server` : les deux ensemble feraient échouer `nginx -t` sur
`a duplicate default server for 0.0.0.0:80`. Le retrait du miroir et le
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

`carlys.example` est le seul motif à remplacer : les trois sous-domaines de
chaque fichier en découlent. Il n'y a plus de chemin de certificat à
substituer, ces fichiers n'en nomment aucun.

Ces vhosts déclarent l'amont de l'admin et celui de MinIO, mais **pas** celui de
l'API : elle tourne en plusieurs exemplaires sur des ports que Docker attribue
dans une plage, et c'est `carlysctl` qui écrit la liste réelle dans
`/etc/nginx/conf.d/carlys-<env>-api-upstream.conf`. `setup.sh` en a posé une
version à un exemplaire à l'étape 2, sans quoi `nginx -t` échouerait ici sur
*host not found in upstream*. Le détail est dans
[orchestration.md](orchestration.md#8-lamont-nginx-est-engendré).

Le snippet `carlys-proxy.conf` n'est pas un détail de rangement : c'est lui qui
porte les en-têtes de proxy des six vhosts — dont `X-Forwarded-For` en mode
**ajout** (`$proxy_add_x_forwarded_for`, le second saut) et `X-Forwarded-Proto:
https` en dur. Oublier de le copier fait échouer `nginx -t` sur un `include`
introuvable, ce qui est le bon comportement : mieux vaut un Nginx qui refuse de
recharger qu'un Nginx qui sert sans l'adresse du client.

Retirez le miroir **avant de recharger**, puis rechargez une seule fois.
L'ordre n'est pas cosmétique : outre le `default_server` en double, laisser les
deux jeux actifs ferait ignorer par Nginx les `server_name` en double
(`conflicting server name … ignored`).

```bash
sudo rm /etc/nginx/sites-enabled/carlys-miroir.conf
sudo nginx -t && sudo systemctl reload nginx
```

**Vérification** — `nginx -t` doit dire `test is successful`. À ce stade les
six noms répondent, toujours en `https://` puisque c'est gra6 qui sert le
client, mais rien ne tourne encore derrière. **Attention, ils ne répondent pas
tous la même chose**, et c'est voulu :

| Ce que vous demandez | Réponse attendue | Pourquoi |
| --- | --- | --- |
| `api…/health/live`, `app…/` | **502** | le vhost proxifie, l'amont est absent |
| la racine `/` de `api…` ou `media…` | **404** | aucune `location` ne couvre `/` : seuls des préfixes précis sont servis |
| `media…/carlys-media/` | **404** | la racine du bucket est fermée exprès — c'est l'URL d'un `ListObjects` S3, pas celle d'un média |

Ouvrir `https://media.carlys.example/` pour « contrôler ses six noms » rend
donc 404, et ce 404 est le bon signe. Contrôlez avec les chemins ci-dessous.

```bash
# Depuis votre poste, à travers gra6 : ce 502 est le NÔTRE (le vhost a bien
# routé, l'amont manque). Le test 2 ci-dessus a déjà écarté celui de gra6.
curl -sI https://api-staging.carlys.example/health/live | head -1   # 502 attendu

# Le miroir a disparu avec le rechargement — c'est la preuve qu'on sert bien
# les vhosts définitifs et plus le vhost temporaire :
curl -s -o /dev/null -w '%{http_code}\n' \
  https://api-staging.carlys.example/miroir                        # 404
```

L'attrape-tout se contrôle **sur le serveur**, en boucle locale : le domaine nu
n'est délibérément pas dans le DNS du §1, et le pare-feu n'autorise que gra6 à
frapper le port 80 depuis l'extérieur. `--resolve` évite la résolution DNS —
sans lui, curl sortirait en 6 (« Could not resolve host »), un code qui ne dit
rien de l'attrape-tout et qu'on prendrait à tort pour sa panne. C'est
exactement le cas d'une requête arrivée en direct avec un `Host` qu'on ne sert
pas :

```bash
curl -si --resolve carlys.example:80:127.0.0.1 \
  http://carlys.example/ ; echo "code curl = $?"   # 52 : connexion fermée, rien renvoyé

# …et le même appel sur un nom servi, lui, atteint bien son vhost :
curl -s -o /dev/null -w '%{http_code}\n' \
  --resolve api-staging.carlys.example:80:127.0.0.1 \
  http://api-staging.carlys.example/health/live    # 502 : le vhost répond, l'amont manque
```

---

## 7. Premier déploiement de la recette

```bash
sudo /srv/carlys/repo/scripts/server/carlysctl deploy staging <sha12>
```

`carlysctl deploy` appelle `deploy.sh` sans rien y ajouter : les deux formes
sont équivalentes, `carlysctl` est simplement le point d'entrée unique.

Reprenez le `sha12` noté à l'étape 4. `deploy.sh` se connecte au registre, tire
les images, **applique les migrations d'abord** (un échec arrête tout, sans
rien basculer), **charge le catalogue d'exercices** livré avec ce sha (même
règle : un échec arrête tout avant la bascule), démarre les services, attend
que `/health/ready` réponde 200, et n'inscrit le SHA dans `DEPLOYED` qu'en cas
de succès. Si la santé ne répond pas, il revient au SHA précédent.

> **Sauf ici : au PREMIER déploiement, il n'y a pas de SHA précédent.** Le
> filet dont parle le paragraphe ci-dessus n'existe donc pas encore. Si la
> santé ne répond pas, la recette reste debout sur un sha malade, `DEPLOYED`
> n'est pas écrit — et la vérification n°4 ci-dessous répondra « No such file
> or directory », ce qui est normal à ce stade et ne doit pas vous surprendre.
> Corrigez la cause (les journaux la nomment), puis relancez la même commande :
> c'est le deuxième déploiement qui inaugure le retour arrière.

**Vérifications** — les trois doivent passer. Elles s'écrivent en `https://`
comme avant la bascule du TLS, **et c'est bien la bonne adresse** : elles
visent les noms publics, servis par gra6, qui relaie ensuite en clair jusqu'ici.
Rien à changer ici, donc — et surtout pas à passer en `http://` sous prétexte
que le dernier saut est en clair : on éprouve la chaîne telle qu'un client la
parcourt, pas un maillon isolé.

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

Il y a maintenant **deux 502 possibles**, et ils ne se soignent pas au même
endroit. Le nôtre — le vhost a routé, le conteneur ne répond pas — laisse une
ligne dans `/var/log/nginx/access.log` de ce serveur. Celui de gra6 — gra6 n'a
pas pu joindre `172.16.0.158:80` — n'en laisse aucune. C'est ce `tail` qui
tranche, et le test 2 du §6 est exactement le même geste.

**L'adresse du client, à contrôler une fois pour toutes.** Provoquez une entrée
d'audit (une connexion au back-office de recette, par exemple) et lisez
l'adresse enregistrée : elle doit être la vôtre, pas celle de gra6. Si c'est
celle de gra6, `TRUST_PROXY_HOPS` ne vaut pas `2` (§5) ; si c'est une adresse
qui n'a aucune raison d'exister, gra6 ajoute `X-Forwarded-For` au lieu de
l'écraser (§6, test 4).

### Le premier administrateur

Le back-office est servi sur `https://app-staging.<domaine>/login` — mais à ce
stade **personne ne peut s'y connecter**, et ce n'est pas un oubli de
configuration : un déploiement applique le schéma et charge le catalogue
d'exercices, mais il n'exécute jamais le seed de développement — celui qui
crée des comptes —, et l'API n'expose aucune route de création de compte
(un administrateur ne se crée pas depuis l'interface qu'il administre). Rôles,
permissions et comptes n'existent donc que si on les crée, par la commande
embarquée dans l'image API :

```bash
sudo /srv/carlys/repo/scripts/server/carlysctl admin-create staging vous@exemple.fr
```

Le mot de passe est **saisi sans écho, puis confirmé** — il ne passe ni en
argument (lisible dans `/proc/<pid>/cmdline` par tout utilisateur local) ni en
variable d'environnement. Laissez la saisie vide pour qu'il soit engendré et
affiché **une seule fois**, sur votre terminal et nulle part ailleurs.

Le compte reçoit le rôle `superadmin` par défaut. Pour un collègue au
périmètre plus étroit : `--role support` (comptes, audit, signalements) ou
`--role content-manager` (catalogue et médias). Un mot de passe oublié se
remplace avec `--reset-password` ; sans ce drapeau, la commande **refuse** de
toucher un compte existant.

C'est ce compte qui sert au contrôle de l'adresse du client ci-dessus, et à
tout ce qui suit dans le back-office. La même commande vaut pour la production,
le jour venu : `admin-create production …` — les rôles et permissions y sont
projetés au premier appel, comme ici.

### Le catalogue d'exercices

**Rien à faire : le déploiement s'en charge.** Contrairement au premier
administrateur ci-dessus, le catalogue (groupes musculaires, matériels, 170
exercices publiés et leurs photos, déposées dans MinIO) n'est pas une donnée
d'exploitation à créer une fois — c'est du **contenu livré avec le code**, au
même titre que le schéma. `deploy.sh` le charge donc à chaque déploiement,
étape 5/7, juste après les migrations et **avant** la bascule : la version qui
prend le trafic trouve le catalogue de sa propre livraison. Les trois chemins
de déploiement passent par là — mise à jour automatique, `promote`, `carlysctl
deploy` —, il n'y a donc aucune commande à retenir après un `git push`.

L'opération est **idempotente** : les exercices sont mis à jour par slug,
jamais dupliqués, et les photos re-déposées sous le même identifiant. Chaque
exercice et ses liaisons sont écrits dans une **transaction** — une
interruption laisse donc des exercices entiers, jamais un exercice publié sans
groupe musculaire. La commande purge elle-même le cache Redis du catalogue, de
sorte que l'application voit le résultat immédiatement, pas dans une heure.

Un échec **arrête le déploiement**, exactement comme un échec de migration :
rien n'est basculé, l'ancienne version continue de servir. Attention toutefois
à ce que « rien n'est basculé » veut dire ici : les textes sont chargés
**avant** les photos, donc un échec du stockage objet laisse en base le
catalogue du nouveau sha, servi avec les anciennes photos. Le message d'erreur
le dit, et la marche à suivre est la même dans tous les cas — corriger, puis
redéployer.

Deux causes possibles, de conséquences différentes : MinIO **tombé**, et le
déploiement aurait de toute façon échoué à la bascule puisque l'API en dépend
(`depends_on`) ; ou des variables `S3_*` **fausses** alors que MinIO va bien —
ce cas-là ne bloquait rien auparavant et bloque désormais le déploiement,
puisque les photos ne peuvent pas partir. C'est voulu : une bibliothèque
d'exercices sans illustrations n'est pas une livraison réussie.

Une limite à connaître, enfin : le chargement **ne dépublie pas**. Un exercice
ou un matériel retiré du code reste visible en base ; l'effacer est un geste
d'administration, pas un effet de bord du déploiement.

Trois échappatoires, pour les cas où l'on veut agir autrement :

```bash
# recharger le catalogue SANS redéployer — voir l'avertissement ci-dessous
sudo /srv/carlys/repo/scripts/server/carlysctl catalog-seed staging

# ne charger que les textes, sans le stockage objet
sudo /srv/carlys/repo/scripts/server/carlysctl catalog-seed staging --sans-photos

# basculer sans toucher au catalogue (il reste celui d'avant)
sudo CARLYS_DEPLOY_CATALOG=non /srv/carlys/repo/scripts/server/carlysctl deploy staging <sha12>
```

> **`catalog-seed` charge le catalogue de la version DÉPLOYÉE**, celle que le
> `.env` désigne — et `deploy.sh` n'y écrit le nouveau sha qu'au **succès**.
> Après un déploiement interrompu à l'étape du catalogue, cette commande
> rechargerait donc le catalogue du sha **précédent**, en donnant l'illusion
> d'avoir réparé quelque chose. Dans ce cas précis : corriger la cause et
> **redéployer**. Une fois la bascule réussie, la commande reprend tout son
> sens — c'est le bon outil pour rattraper des photos après avoir réparé le
> stockage objet.

Strictement le catalogue, dans tous les cas : aucun compte, aucun plan
d'abonnement n'est créé. Et tout ceci vaut pour la production sans changement,
le jour venu.

### La boîte aux lettres de la recette

Les e-mails de recette ne partent nulle part : ils atterrissent dans Mailpit.
Il n'est proxifié par **aucun** vhost, et c'est délibéré — il affiche en clair
tous les liens de vérification et de réinitialisation. Pour le consulter,
depuis votre poste :

```bash
ssh -L 8025:127.0.0.1:8025 utilisateur@172.16.0.158
# puis http://localhost:8025 dans le navigateur local
```

L'adresse est celle par laquelle vous administrez déjà ce serveur — gra6 n'y
est pour rien : il ne relaie que le port 80, et Mailpit n'est proxifié par
aucun vhost.

---

## 8. Les builds mobiles

> **Fermez la session SSH : tout ce §8 se fait sur VOTRE POSTE**, dans un clone
> du dépôt, jamais sur le serveur. `setup.sh` n'y installe ni Flutter, ni JDK,
> ni Android SDK, et n'a pas à le faire — `bootstrap_mobile.sh` s'y arrêterait
> aussitôt sur « Le SDK Flutter est requis ». Les prérequis du poste (SDK
> épinglé **3.44.9**, Android SDK, licences, `flutter doctor`) sont dans
> [`docs/development/poste-de-travail.md`](../development/poste-de-travail.md).

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

Les flavors acceptés sont exactement `development`, `staging` et
`production`. Une valeur inconnue **ne casse pas le build** : elle retombe
silencieusement sur `development`. Écrivez-les correctement.

`CARLYS_API_BASE_URL` s'écrit **sans** le préfixe `/api/v1`, que l'application
ajoute elle-même.

**Le filet, et sa limite.** En `staging` comme en `production`, l'application
refuse de démarrer si `CARLYS_API_BASE_URL` **ou** `CARLYS_PUBLIC_WEB_BASE_URL`
manque ou pointe en local — `localhost`, `127.0.0.1` et `10.0.2.2`, la boucle
locale de l'émulateur Android, sont traités pareil. Sans ce filet, l'oubli de
l'adresse du web embarquerait deux liens légaux morts, ceux-là mêmes qu'un
examinateur de magasin ouvre ; et l'oubli de l'adresse de l'API serait pire
encore, puisqu'il ne se voit nulle part : l'application démarre, puis chaque
appel réseau part sur `localhost:3000`, adresse qui n'existe pas sur un
téléphone et qu'Android bloque de toute façon en release. Elle paraît
« lente », puis « hors ligne ».

`CARLYS_FLAVOR`, en revanche, n'est **pas** contrôlé : une valeur inconnue
retombe silencieusement sur `development`. C'est la seule des trois qui exige
votre attention plutôt que celle du programme.

Attention enfin : ce contrôle a lieu **au lancement, pas à la compilation**.
Le build réussit, l'`.aab` ou l'`.ipa` se produit normalement, et c'est la
première ouverture qui échoue. **Lancez toujours l'artefact une fois avant de
le déposer.**

### Recette — TestFlight et piste interne

```bash
# Android → Galaxy Store, ou piste interne Play
flutter build appbundle --release \
  --dart-define=CARLYS_FLAVOR=staging \
  --dart-define=CARLYS_API_BASE_URL=https://api-staging.carlys.example \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://app-staging.carlys.example
# → build/app/outputs/bundle/release/app-release.aab
#
# ATTENTION : ce bundle est signé avec la clé de DEBUG. Le dépôt ne versionne
# pas `android/` (bootstrap_mobile.sh le régénère), donc aucun keystore ni
# aucune `signingConfig` n'y survit. La Play Console refuse un bundle signé en
# debug. Avant la première soumission : créer un keystore, le ranger HORS du
# dépôt, déclarer sa signingConfig dans android/app/build.gradle.kts (le
# gabarit de Flutter 3.44 est en Kotlin DSL) — et savoir que ce fichier sera
# écrasé au prochain bootstrap_mobile.sh. La CI, elle, fait ce branchement
# toute seule depuis les secrets : voir builds-mobiles.md §4.

# iOS → TestFlight. macOS OBLIGATOIRE, avec Xcode et un compte Apple Developer.
flutter build ipa --release \
  --dart-define=CARLYS_FLAVOR=staging \
  --dart-define=CARLYS_API_BASE_URL=https://api-staging.carlys.example \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://app-staging.carlys.example
# → build/ios/ipa/*.ipa, à téléverser avec Transporter ou `xcrun altool`
```

**La CI fait ces deux gestes pour vous**, secrets posés : `mobile-recette`
signe le bundle avec le keystore des secrets, et son job iOS, sur un runner
macOS de GitHub, signe l'`.ipa`. Le dépôt sur les magasins — piste interne
Play, TestFlight — n'a lieu que sur une exécution manuelle avec la case
**publier** : aucune poussée ne publie. Ce que chaque chemin exige est dans
[`builds-mobiles.md`](builds-mobiles.md), §4 pour Android, §10 pour iOS. Les
commandes ci-dessus restent le pendant **local**, utile pour compiler sans
attendre la CI.

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

> **Ces quatre valeurs sont celles d'ANDROID.** `google-services.json` décrit
> l'application Android ; l'équivalent iOS est `GoogleService-Info.plist`, et
> son `appId` diffère. Injecter le fichier Android dans un build iOS ne laisse
> pas le push « simplement inactif » : l'application se croit configurée,
> tente l'enregistrement, et échoue dans un simple avertissement de journal.
> Prévoyez **deux fichiers**, un par plateforme.

### Ce qui n'est pas automatisable

- **iOS exige un macOS.** Ce serveur ne produira jamais un `.ipa` ; c'est une
  contrainte d'Apple, pas un manque du dépôt. Le runner macOS de GitHub, lui,
  le peut — sur demande et à dix fois le prix d'une minute Linux
  (`builds-mobiles.md`, §10.5).
- **La création des pièces de signature** (keystore Android, certificat et
  profil Apple, clés API des magasins) et celle des comptes Apple Developer,
  Google Play Console et Samsung Seller restent manuelles. Leur **usage**, lui,
  est automatisé : posées en secrets, la CI signe et dépose sur la piste
  interne Play et sur TestFlight.
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
- **SMTP** : un vrai relais, **acceptant ce serveur sans authentification** —
  la contrainte est détaillée au §5, « Les e-mails de production », et elle
  écarte la plupart des fournisseurs grand public. Mailpit n'existe pas ici :
  il est sous profil `staging`. Un `SMTP_HOST` qui ne route nulle part rendrait
  la vérification d'adresse et la réinitialisation de mot de passe
  **silencieusement** inopérantes.

### 9.3 Faire passer les textes légaux PAR la recette

C'est le point où la première mise en production dérape si l'on va trop vite,
et la raison tient en une phrase : **compléter les textes légaux crée un
nouveau commit**. Appelons `A` le sha que la recette fait tourner depuis le
§7, et `B` celui qui porte vos textes.

`images-publish-prod` fait `git checkout --detach` sur le sha qu'on lui donne
et lit `docs/legal/` **de ce commit**. Lancé sur `A`, il échoue donc à coup
sûr : `A` contient encore tous les marqueurs. Et `promote.sh` sans argument
relit `/srv/carlys/staging/DEPLOYED`, qui vaut toujours `A` : il chercherait
une image `sha-A-prod` qui n'a jamais été construite.

Autrement dit, `B` doit d'abord **passer par la recette**. Ce n'est pas une
formalité administrative : c'est la règle « on construit une fois, on déploie
deux fois » appliquée à la lettre — la production ne doit redéployer que des
octets qu'on a vus tourner.

```bash
# 1. Sur votre poste : compléter docs/legal/*.md, commiter, POUSSER.
#    images-publish publie alors les trois images du sha B.

# 2. Sur le serveur : rafraîchir le clone, puis faire tourner B en recette.
sudo git -C /srv/carlys/repo pull --ff-only
sudo /srv/carlys/repo/scripts/server/deploy.sh staging <B>

# 3. Vérifier que la page légale est bien complète EN RECETTE :
#    https://app-staging.carlys.example/privacy — aucun [À COMPLÉTER].

# 4. Actions → images-publish-prod → Run workflow, champ « sha » = B.
#    Il refuse encore si un marqueur subsiste, et il vous les liste.

# 5. Enfin, la bascule.
```

`/srv/carlys/staging/DEPLOYED` vaut désormais `B`, donc `promote.sh` sans
argument promeut bien `B`. Il accepte aussi un sha explicite —
`promote.sh <sha>` — mais s'en servir pour promouvoir autre chose que ce que
la recette fait tourner contredit la règle ci-dessus.

Le workflow vérifie au passage que les images d'API de ce sha existent déjà :
la production **redéploie les octets éprouvés en recette, elle ne reconstruit
rien**. Il construit ensuite l'admin garde armée et publie
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

### Ce que le serveur fait désormais sans vous

Depuis l'étape 2, une minuterie systemd passe **toutes les deux minutes** et :

- relève un conteneur disparu, arrêté, ou « unhealthy » deux passages de suite
  — avec un plafond de cinq réparations par heure, au-delà duquel elle
  **s'arrête et le dit** plutôt que de masquer une panne qui revient ;
- ajuste le nombre d'exemplaires de l'API à la charge mesurée (utilisateurs en
  ligne, débit, latence) ;
- tient l'amont Nginx à jour après chaque changement.

Elle **ne déploie rien**. Pour regarder ce qu'elle voit :

```bash
sudo /srv/carlys/repo/scripts/server/carlysctl status
sudo journalctl -u carlys-supervision.service -f
```

Tout est détaillé dans **[orchestration.md](orchestration.md)** : la formule de
mise à l'échelle et ses garde-fous, le plafond de réparations, et comment
activer la mise à jour automatique — y compris en production, où elle promeut
la recette après maturation plutôt que de suivre une branche.

### Déployer une nouvelle version

1. Poussez. `images-publish` publie les trois images du nouveau SHA.
2. **Mettez à jour le clone du serveur.** C'est la première chose à faire, et
   la plus facile à oublier :

   ```bash
   sudo git -C /srv/carlys/repo pull --ff-only
   ```

3. `sudo /srv/carlys/repo/scripts/server/carlysctl deploy staging <nouveau-sha12>`
4. Éprouvez la recette.
5. Lancez `images-publish-prod` sur ce SHA, puis `carlysctl promote`.

**Si `deploy.sh` refuse avec « Image introuvable ».** Le sha n'a pas d'images :
son exécution a été annulée — GitHub annule l'exécution en attente d'un groupe
de concurrence dès qu'une nouvelle arrive, ce qui frappe les commits du
*milieu* d'une rafale — ou le runner est tombé. La réparation n'est PAS de
relancer `images-publish` sur la branche, qui publierait la tête et pas ce
commit : Actions → `images-publish` → *Run workflow* → **renseignez le sha
dans le champ prévu**. Le tag mouvant `staging` n'est pas déplacé dans ce cas.
Rien n'a été déployé entre-temps : `deploy.sh` meurt avant de toucher
l'environnement.

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
quand c'est le cas ; en son absence, ce `git pull` suffit. Le snippet partagé
`snippets/carlys-proxy.conf` suit la même règle et se copie séparément : c'est
lui qui porte les en-têtes dont dépend l'adresse du client.

**Et la configuration de gra6 n'est dans aucun de ces dépôts.** Un changement
qui touche les en-têtes attendus de lui — les trois du §6 — doit être porté
là-bas à la main, par qui en a l'accès. Le §6 dit comment vérifier qu'il a bien
été porté, et ces tests se rejouent à tout moment.

**Toujours par SHA, jamais par tag mouvant.** Le tag `staging` existe pour
qu'on voie d'un coup d'œil ce qui est récent dans l'onglet Packages ; s'en
servir pour déployer ferait diverger la recette et la production sans qu'on
puisse dire quand.

### Sauvegardes

`setup.sh` installe une tâche quotidienne qui appelle `backup.sh` :
`pg_dump` des deux bases dans `/srv/carlys/backups/`, horodaté, rétention
14 jours.

**La rétention n'est appliquée QUE pour un environnement ayant produit un dump
neuf et valide cette nuit-là.** Sans cette condition, une panne discrète —
mot de passe changé dans le `.env` mais pas dans la base, disque plein — finit
par effacer la dernière sauvegarde restaurable : quinze nuits d'échec, et le
dernier dump valable franchit `-mtime +14`.

> **Conséquence à connaître : des dumps qui s'accumulent au-delà de 14 jours
> ne signalent PAS une purge en panne.** C'est le contraire — c'est le signe
> que la sauvegarde nocturne échoue, et que le script protège ce qui reste.
> Ne les supprimez surtout pas à la main : ce sont peut-être les derniers.
> Cherchez la cause d'abord.

```bash
ls -lh /srv/carlys/backups/ | tail -5

# Ce que la tâche de cette nuit a vraiment fait — c'est là que se lit un échec
# silencieux, le courriel de cron finissant souvent dans un filtre :
sudo journalctl -u cron --since yesterday | grep -i carlys

sudo /srv/carlys/repo/scripts/server/backup.sh   # à la demande, sortie 1 si échec
```

Une sauvegarde jamais restaurée n'est pas une sauvegarde : testez une
restauration sur la base de recette de temps en temps.

### Certificats

Rien à faire ici : les certificats des six noms vivent sur **gra6**, qui les
émet, les renouvelle et recharge sa propre configuration. Ce serveur n'en
détient aucun et n'a aucune minuterie à surveiller. Un certificat expiré se
constate sur les six noms à la fois, depuis n'importe quel navigateur, et se
répare sur gra6.

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
| `nginx -t` échoue sur un `ssl_certificate` ou `/etc/letsencrypt/…` | un vhost d'une installation antérieure traîne dans `sites-enabled/` : plus aucun fichier du dépôt ne nomme de certificat. Listez `/etc/nginx/sites-enabled/` et retirez l'intrus |
| `nginx -t` échoue sur un `include` introuvable | `snippets/carlys-proxy.conf` n'a pas été copié (étape 6) — et il vaut mieux ce refus qu'un Nginx qui servirait sans l'adresse du client |
| 502 **sans ligne dans `/var/log/nginx/access.log`** d'ici | c'est le 502 de gra6 : il ne joint pas `172.16.0.158:80`. Pare-feu (`CARLYS_PROXY_CIDR`, étape 2), Nginx arrêté, ou mauvaise adresse dans son `proxy_pass` |
| 502 sur tous les hôtes, **avec** une ligne dans l'`access.log` | aucun conteneur ne tourne : le déploiement a échoué ou n'a pas eu lieu |
| 502 sur l'API seule | refus de démarrage sur une variable — `docker compose logs api` la nomme |
| Les six noms rendent une connexion fermée, alors que les conteneurs tournent | gra6 ne conserve pas le `Host` : aucun `server_name` ne correspond, tout tombe sur l'attrape-tout. `proxy_set_header Host $host;` sur gra6 (§6, test 3) |
| Le back-office s'affiche mais reste vide | l'image admin vise la mauvaise API. Trois causes, dans cet ordre : `CARLYS_DOMAIN` **mal formée** (avec `https://`, une barre finale ou un port — le workflow refuse les cas nets, pas tous) ; la variable posée APRÈS la construction de cette image, qui garde donc `localhost:3000` ; ou `CORS_ORIGINS` côté API qui ne couvre pas l'origine de l'admin, auquel cas la console du navigateur montre des erreurs CORS. Vérifiez la console avant tout : elle distingue les trois en une seconde |
| Les liens des e-mails pointent en local | `PUBLIC_APP_URL` mal renseignée |
| L'app mobile plante au lancement | `CARLYS_PUBLIC_WEB_BASE_URL` oubliée au build (étape 8) |
| `promote.sh` dit que le tag `-prod` manque | les marqueurs légaux subsistent (étape 9.1) |
| L'IP du client est toujours la même dans l'audit, et c'est celle de gra6 | `TRUST_PROXY_HOPS` ≠ 2 (§5), ou gra6 ne pose pas `X-Forwarded-For` du tout |
| Des adresses aberrantes dans l'audit, ou une limitation de débit qui ne freine personne | gra6 **ajoute** `X-Forwarded-For` au lieu de l'écraser : n'importe qui choisit l'adresse qu'on lui attribue. `proxy_set_header X-Forwarded-For $remote_addr;` sur gra6 (§6, test 4) |
| Un service, un volume ou une variable manque après un déploiement pourtant réussi | le clone `/srv/carlys/repo` n'a pas été mis à jour : `deploy.sh` a tiré les bonnes images et les a démarrées sous un `compose.yml` périmé (étape 10) |
| Un hôte inconnu (domaine nu, `www`, `Host` forgé en direct) atteint l'API de production | le vhost attrape-tout n'est pas activé (étape 6) — et, pour l'accès direct, le port 80 n'est pas restreint à gra6 (étape 2) |
| Certificat expiré sur les six noms | rien à faire ici, ce serveur n'en détient aucun : c'est gra6 qui émet et renouvelle (étape 10, « Certificats ») |
| `nginx -t` échoue sur `host not found in upstream "carlys_api_…"` | l'amont engendré manque dans `/etc/nginx/conf.d/` : rejouez `setup.sh`, ou `carlysctl heal <env>` si la pile tourne déjà ([orchestration.md](orchestration.md#8-lamont-nginx-est-engendré)) |
| 502 alors que `docker compose ps` montre l'API en bonne santé | Nginx sert d'anciens ports : `carlysctl status` affiche la ligne `⚠ ÉCART nginx ↔ réalité`, `carlysctl heal <env>` la corrige |
| `carlysctl status` dit `aucun exemplaire ne rend /metrics` | en production, `METRICS_TOKEN` manque dans le `.env` — la supervision voit encore la santé, mais plus la charge |

## À lire à côté

- [`docs/deployment/orchestration.md`](orchestration.md) — ce que le serveur fait tout seul : supervision, réparation, mise à l'échelle, mise à jour automatique.
- [`docs/deployment/builds-mobiles.md`](builds-mobiles.md) — compiler l'application de recette et celle de production.
- [`infrastructure/deployment/README.md`](../../infrastructure/deployment/README.md) — pourquoi les migrations tournent avant la bascule, et comment l'arbre de production est fabriqué.
- [`infrastructure/nginx/README.md`](../../infrastructure/nginx/README.md) — ce que garantissent les vhosts.
- [`infrastructure/nginx/snippets/carlys-proxy.conf`](../../infrastructure/nginx/snippets/carlys-proxy.conf) — les en-têtes de proxy eux-mêmes, chacun commenté avec ce qui a été mesuré.
- [`docs/security/reverse-proxy.md`](../security/reverse-proxy.md) — l'adresse du client, les en-têtes de proxy, les limites de taille.
- [`apps/mobile/README.md`](../../apps/mobile/README.md) — configuration d'exécution de l'application.

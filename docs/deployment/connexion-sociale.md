# Connexion Apple et Google — mise en route

Les boutons « Continuer avec Apple » et « Continuer avec Google » sont livrés
et **branchés** : ils demandent un jeton d'identité au fournisseur et le
confient à l'API, qui le vérifie et ouvre une session Carlys ordinaire.

Tant que les identifiants ci-dessous ne sont pas fournis, rien ne casse : le
bouton concerné annonce qu'il n'est **pas encore disponible** et renvoie vers
la connexion par e-mail. C'est le même parti pris que le coach IA — une
fonctionnalité non configurée se tait proprement, elle n'empêche jamais l'API
de démarrer ni l'application de fonctionner.

## Ce qu'il faut savoir avant de commencer

| Question | Réponse |
| --- | --- |
| Ces identifiants sont-ils des secrets ? | **Non.** Un client ID OAuth et un bundle ID voyagent dans l'application, n'importe qui peut les lire. Ils restent hors du dépôt parce qu'ils sont propres à ton projet, pas parce qu'ils sont sensibles. |
| Qui décide qu'une connexion est valide ? | **Le serveur, toujours.** Il vérifie la signature du jeton contre les clés publiques du fournisseur, l'émetteur, l'audience et l'expiration. Un jeton fabriqué sur l'appareil est refusé. |
| Apple est-il obligatoire ? | **Oui, sur iOS**, dès lors qu'un autre fournisseur tiers est proposé (règle de l'App Store). Sur Android, le bouton Apple dit simplement que cette connexion n'existe que sur iPhone et iPad. |
| Peut-on n'activer que Google ? | Oui. Chaque fournisseur a sa propre variable ; l'un marche sans l'autre. |

## 1. Google

### 1.1 Créer le projet et l'écran de consentement

1. Ouvre <https://console.cloud.google.com/> et crée un projet (ou reprends
   celui de Firebase, si tu l'as déjà créé pour les notifications).
2. **APIs & Services → OAuth consent screen** : type « External », renseigne le
   nom de l'application (Carlys), l'adresse d'assistance et les liens
   `/privacy` et `/terms` de ton domaine. Tant que l'écran reste en « Testing »,
   seuls les comptes ajoutés en « Test users » peuvent se connecter.

### 1.2 Créer les clients OAuth

**APIs & Services → Credentials → Create credentials → OAuth client ID.**

Il en faut **deux** — c'est le point qui piège tout le monde :

| Type | À quoi il sert | Ce qu'on en fait |
| --- | --- | --- |
| **Web application** | C'est l'AUDIENCE du jeton, donc l'identité du SERVEUR | Son client ID va dans `GOOGLE_OAUTH_CLIENT_IDS` (API) **et** dans `CARLYS_GOOGLE_SERVER_CLIENT_ID` (mobile) |
| **Android** | Autorise l'application signée à demander un jeton | Rien à recopier : il est reconnu par le nom de paquet et l'empreinte |
| **iOS** (le jour où l'app iOS existe) | Sur iOS, le SDK émet un jeton dont l'audience est CE client — pas le « Web » | Son client ID s'ajoute à `GOOGLE_OAUTH_CLIENT_IDS`, séparé par une virgule |

Pour le client Android, Google demande :

- **Package name** : `com.carlys.carlys_mobile`. C'est `flutter create --org
  com.carlys --project-name carlys_mobile` (voir `scripts/mobile_platforms.sh`)
  qui le décide — Android reçoit le nom tel quel, iOS en camelCase
  (`com.carlys.carlysMobile`). À recopier exactement : une lettre de travers
  et Google refuse le jeton sans rien expliquer ;
- **SHA-1 certificate fingerprint** : l'empreinte de la clé qui signe l'APK.

Il en faut **une par clé de signature**, et il y en a deux :

**1. La clé d'upload** (celle des secrets GitHub `ANDROID_KEYSTORE_BASE64`).
Le plus simple, si tu n'as plus le fichier sous la main : lance
`mobile-recette` et lis son récapitulatif — l'étape « Empreintes de la clé de
signature » les affiche à chaque exécution signée, SHA-1 et SHA-256. Rien n'y
est secret : une empreinte est un condensé de la partie PUBLIQUE de la clé.

Sinon, depuis ta sauvegarde base64 (gestionnaire de mots de passe) :

```bash
# Le keystore n'a pas besoin d'exister ailleurs qu'en mémoire de la commande.
printf %s "<la-ligne-base64>" | base64 -d > /tmp/upload.jks
keytool -list -v -keystore /tmp/upload.jks -alias upload | grep -E 'SHA1|SHA256'
shred -u /tmp/upload.jks   # on ne laisse pas traîner une clé de signature
```

**2. La clé de Play App Signing** (Google re-signe les installations du
Store) : Play Console → ton app → Test and release → Setup → App signing →
« SHA-1 certificate fingerprint » de l'« App signing key certificate ».
Cette seconde empreinte n'existe qu'une fois l'application déposée sur le
Store ; tant que tu installes l'APK toi-même, la première suffit.

> Oublier la seconde est l'erreur classique : la connexion marche avec l'APK
> qu'on installe soi-même, et échoue pour tous ceux qui installent depuis le
> Store. Ajoute les deux empreintes dès maintenant.

### 1.3 Renseigner les deux côtés

**Serveur** — dans le `.env` de l'API (voir `apps/api/.env.example`) :

```bash
# Le client « Web ». On peut en mettre plusieurs, séparés par des virgules
# (utile si un client iOS distinct est créé plus tard).
GOOGLE_OAUTH_CLIENT_IDS=000000000000-xxxx.apps.googleusercontent.com
```

Puis **redéploie**, faute de quoi la ligne ne sera jamais lue : un conteneur
reçoit son environnement à sa CRÉATION, pas à chaque requête.

```bash
# `carlysctl update` ne suffit PAS : voyant le même sha déjà déployé, il
# répond « déjà sur sha-… » et s'arrête sans rien recréer. C'est le
# redéploiement du sha COURANT qu'il faut — même code, conteneurs neufs.
SHA=$(sudo /srv/carlys/repo/scripts/server/carlysctl status staging \
      | grep -oE 'sha-[0-9a-f]+' | head -1 | cut -d- -f2)
sudo /srv/carlys/repo/scripts/server/carlysctl deploy staging "$SHA"
```

Pour vérifier que le conteneur la voit vraiment :

```bash
sudo docker ps --filter label=com.carlys.environment=staging --format '{{.Names}}' \
  | grep api | head -1 | xargs -r -I{} sudo docker exec {} printenv GOOGLE_OAUTH_CLIENT_IDS
# vide → le conteneur n'a pas été recréé depuis l'ajout de la ligne
```

**Mobile** — variable de dépôt GitHub, lue par `mobile-recette.yml` :

*Settings → Secrets and variables → Actions → **Variables** → New variable*

| Nom | Valeur |
| --- | --- |
| `CARLYS_GOOGLE_SERVER_CLIENT_ID` | le **même** client « Web » qu'au serveur |

En local :

```bash
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://localhost:3000 \
  --dart-define=CARLYS_GOOGLE_SERVER_CLIENT_ID=000000000000-xxxx.apps.googleusercontent.com
```

## 2. Apple

Apple ne s'active que sur iOS, et réclame un **compte Apple Developer payant**
(99 $/an). Tant que le projet n'a pas de build iOS, cette section peut attendre
— le bouton Apple dira de lui-même qu'il n'est pas disponible.

1. <https://developer.apple.com/account> → **Certificates, Identifiers &
   Profiles → Identifiers** : sur l'App ID de Carlys
   (`com.carlys.carlysMobile` — la forme iOS, en camelCase),
   coche la capacité **Sign in with Apple**.
2. Dans Xcode, onglet **Signing & Capabilities** du runner iOS : ajoute la
   capacité **Sign in with Apple**. (Le dossier `ios/` est engendré par
   `./scripts/bootstrap_mobile.sh` : la capacité se repose après
   regénération, ou se scripte dans le `project.pbxproj` versionné.)
3. Côté serveur, l'audience du jeton est le **bundle ID** :

```bash
APPLE_OAUTH_AUDIENCES=com.carlys.carlysMobile
```

> Si un jour la connexion Apple est proposée sur le web, ajoute aussi le
> **Services ID** (`com.carlys.web`, par exemple) à la même liste, séparé par
> une virgule.

> Le workflow `mobile-recette.yml` LIT ce bundle depuis le projet engendré
> plutôt que de le recopier : la valeur ci-dessus est celle qu'il trouve
> aujourd'hui, et son récapitulatif d'exécution l'affiche à chaque build iOS.

## 3. Vérifier

```bash
# Un jeton bidon doit donner 401 : la preuve que le fournisseur EST configuré
# et que la vérification tourne pour de bon. Lis le CORPS, pas seulement le
# code — un 503 d'nginx (API qui redémarre) et un 503 de l'API (« fournisseur
# pas configuré ») portent le même chiffre et ne veulent pas dire la même
# chose. Le nôtre est du JSON, code SERVICE_UNAVAILABLE ; celui d'nginx est
# du HTML.
curl -s -X POST https://api.<domaine>/api/v1/auth/social \
  -H 'Content-Type: application/json' \
  -d '{"provider":"google","idToken":"pas-un-vrai-jeton"}'
# 401 UNAUTHORIZED      → configuré : le faux jeton a bien été refusé
# 503 SERVICE_UNAVAILABLE (JSON) → GOOGLE_OAUTH_CLIENT_IDS absent, ou .env
#                                  ajouté sans redéploiement (voir §1.3)
# 503 en HTML           → nginx : l'API ne répond pas encore, réessaie
```

Sur le téléphone, le bouton doit ouvrir la feuille Google, puis l'application
doit entrer directement dans l'accueil. En cas de refus, le message affiché dit
lequel des deux côtés manque.

## 4. Ce que fait le serveur, exactement

`POST /api/v1/auth/social` (`apps/api/src/modules/auth/application/`) :

1. **Audience configurée ?** Sinon `503` — et le jeton n'est même pas regardé :
   vérifier sans audience attendue reviendrait à accepter n'importe laquelle.
2. **Vérification du jeton** (`social-token-verifier.ts`) : signature contre le
   trousseau public du fournisseur (récupéré et mis en cache par `jose`,
   rotation gérée), émetteur attendu, audience dans la liste, expiration.
   Tout échec est un `401` sans détail.
3. **À qui ouvrir la session** (`social-auth.service.ts`), dans cet ordre :
   - l'identité `(fournisseur, sub)` est connue → connexion ;
   - l'adresse e-mail correspond à un compte existant **et le fournisseur la
     garantit vérifiée** → l'identité est rattachée à ce compte ;
   - sinon → création d'un compte **sans mot de passe** (aucune ligne
     `UserCredential`), adresse marquée vérifiée.
4. **Refus si l'adresse n'est pas vérifiée par le fournisseur** : ni
   rattachement ni création. C'est la garde qui empêche de prendre le compte
   d'autrui avec une adresse revendiquée mais non prouvée.
5. **Rattachement à un compte dont l'adresse n'avait jamais été vérifiée** :
   le compte est REPRIS, pas partagé. N'importe qui peut s'inscrire avec
   l'adresse d'un autre — le compte est utilisable aussitôt, la vérification
   n'étant qu'une bannière. Quelqu'un a donc pu s'installer à l'avance sur
   l'adresse de la personne qui arrive. Le fournisseur, lui, vient de prouver
   la propriété de cette adresse : tout ce qui pouvait appartenir à un tiers
   tombe (sessions ouvertes, mot de passe, réinitialisations en cours), et la
   personne repart d'une porte unique, la sienne. Quand l'adresse était DÉJÀ
   vérifiée des deux côtés, rien n'est retiré : le mot de passe continue de
   fonctionner, deux portes pour une seule maison.

La session émise est **exactement** celle de la connexion par e-mail : mêmes
jetons, même rotation, même révocation par appareil.

## 5. Questions fréquentes

**« J'avais déjà un compte par e-mail, et je me connecte avec Google. »**
C'est le même compte : l'identité Google s'y rattache, et le mot de passe
continue de fonctionner. Deux portes, une seule maison.

**« Un compte créé par Google peut-il se connecter par mot de passe ? »**
Pas tant qu'il n'en a pas : il n'a aucune ligne `UserCredential`. « Mot de
passe oublié » lui en donne un — c'est le chemin prévu, et c'est aussi le
passage obligé pour SUPPRIMER un tel compte, la suppression demandant le mot
de passe. L'API le dit explicitement (409) au lieu de répondre « mot de passe
incorrect » à quelqu'un qui n'en a jamais eu.

**« Apple ne me redonne plus mon nom. »**
Normal : Apple ne transmet le nom qu'à la **toute première** autorisation.
L'application le fait suivre au serveur ce jour-là ; ensuite, il vient du
profil Carlys.

**« Le bouton dit "arrive bientôt" alors que j'ai tout configuré. »**
Quatre causes, dans l'ordre de fréquence : l'API n'a pas été redéployée depuis
l'ajout de la variable ; la variable de dépôt GitHub a été posée après le
dernier build de l'APK (elle est figée dans le binaire) ; le client Android
manque l'empreinte SHA-1 de la clé qui a signé l'APK installé ; ou la variable
de dépôt n'existe pas du tout, auquel cas TOUS les builds — recette comme
production — sortent avec un bouton Google inerte alors que le serveur, lui,
est prêt.

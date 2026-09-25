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
| **iOS** (le jour où l'app iOS existe) | Sur iOS, le SDK émet un jeton dont l'audience est CE client — pas le « Web » | Son client ID s'ajoute à `GOOGLE_OAUTH_CLIENT_IDS`, séparé par une virgule, **et** va dans `CARLYS_GOOGLE_IOS_CLIENT_ID` (mobile) |

> **Le client Android ne se recopie nulle part.** C'est la question qui
> revient, et la réponse est contre-intuitive : il doit exister dans le
> projet — sans lui Google refuse la demande avec `ApiException: 10` —, mais
> son identifiant n'apparaît dans aucun fichier, ni côté serveur ni côté
> mobile. Sur Android, l'application est reconnue à son nom de paquet et à
> l'empreinte de sa clé de signature ; l'identifiant qui voyage dans le jeton
> (`aud`) est celui du client « Web ». L'ajouter à `GOOGLE_OAUTH_CLIENT_IDS`
> élargit la liste des audiences acceptées sans rien permettre de plus.

Pour le client Android, Google demande :

- **Package name** : `com.carlys.carlys_mobile`. C'est `flutter create --org
  com.carlys --project-name carlys_mobile` (voir `scripts/mobile_platforms.sh`)
  qui le décide — Android reçoit le nom tel quel, iOS en camelCase
  (`com.carlys.carlysMobile`). À recopier exactement : une lettre de travers
  et Google refuse le jeton sans rien expliquer ;
- **SHA-1 certificate fingerprint** : l'empreinte de la clé qui signe l'APK.
  Le formulaire n'a qu'**un seul** champ SHA-1.

Il faut donc **un client OAuth Android par clé de signature** : même nom de
paquet, une empreinte différente pour chacun. Ne remplace jamais l'empreinte
d'un client existant pour en poser une autre : l'APK signé par l'ancienne
clé cesserait aussitôt de se connecter. Il y a deux clés (trois avec celle de
debug, pour `flutter run`) :

**1. La clé d'upload** (celle des secrets GitHub `ANDROID_KEYSTORE_BASE64`).
Le plus simple, si tu n'as plus le fichier sous la main : lance
`mobile-recette` et lis son récapitulatif — l'étape « Empreintes de la clé de
signature » les affiche à chaque exécution signée, SHA-1 et SHA-256. Rien n'y
est secret : une empreinte est un condensé de la partie PUBLIQUE de la clé.

Ces empreintes sont lues dans le keystore, pas dans l'APK — elles ne valent
donc que si l'APK porte bien cette clé. C'est ce que prouve l'étape précédente,
« La signature de l'APK est bien la nôtre » : elle compare, avec `apksigner`,
le certificat trouvé DANS l'APK à celui de l'alias du keystore, et fait
échouer l'exécution s'ils diffèrent. Exécution verte ⇒ l'empreinte affichée
est celle de l'APK que tu installes.

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
> Store. Crée les deux clients Android dès que la seconde empreinte existe.

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
| `CARLYS_GOOGLE_IOS_CLIENT_ID` | le client « iOS ». Inutile tant qu'il n'y a pas de build iOS ; sans lui le bouton Google y est annoncé indisponible au lieu de faire lever le SDK |

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
doit entrer directement dans l'accueil. En cas d'échec, la popup donne la cause
en clair **et un code court** (`Code : google-10`, `Code : http-401 · réf.
1a2b3c4d`) : c'est lui qu'il faut recopier, puis chercher au §6.

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
Le code sous la phrase tranche (§6). `http-503` : l'API n'a pas été redéployée
depuis l'ajout de la variable. `google-config-web` : la variable de dépôt
GitHub a été posée après le dernier build de l'APK (elle est figée dans le
binaire), ou elle n'existe pas du tout — auquel cas TOUS les builds, recette
comme production, sortent avec un bouton Google inerte alors que le serveur,
lui, est prêt. `google-sans-jeton` : l'identifiant injecté n'est pas celui du
client « Web ». Une empreinte SHA-1 manquante, elle, ne dit plus « arrive
bientôt » : c'est `google-10`, « Google n’a pas reconnu cette version de
l’application ».

## 6. Diagnostiquer un échec

Chaque échec de connexion Apple ou Google affiche, dans la même popup que la
phrase, une ligne **`Code : …`**. Pour une erreur venue du serveur, elle porte
aussi une **référence** : `Code : http-500 · réf. 1a2b3c4d`, les huit premiers
caractères du `requestId` de la réponse. C'est ce qui retrouve LA ligne de
journal de l'API. La popup reste dix secondes, le temps de recopier le code ou
de faire une capture ; avec un lecteur d'écran (TalkBack, VoiceOver), elle
reste jusqu'à ce qu'on la ferme, le temps d'aller réécouter le code signe à
signe. Renoncer devant la feuille du fournisseur n'affiche rien : ce n'est
pas un échec.

Pourquoi un code à l'écran : dans une build de recette ou de production, les
journaux de l'application (`AppLogger`, via `dart:developer`) ne s'écrivent
nulle part de lisible. L'application journalise quand même chaque échec, une
fois, avec son code et le `requestId` complet — jamais un jeton, jamais une
adresse e-mail —, mais la popup est la seule trace à portée du testeur.

### La première question : le serveur a-t-il vu la requête ?

| Famille | Où l'échec s'est produit | Ligne `POST /api/v1/auth/social` dans les journaux de l'API ? |
| --- | --- | --- |
| `google-*`, `apple-*` | Sur le téléphone, dans le SDK du fournisseur, **avant** tout appel à Carlys | **Non**, et c'est normal |
| `reseau-*` | Entre le téléphone et Carlys | Non (ou coupée) |
| `http-*` **sans** `réf.` | Un intermédiaire (nginx) a répondu à la place de l'API | Non dans l'API ; oui dans `/var/log/nginx/access.log` |
| `http-*` **avec** `réf.` | L'API elle-même | **Oui** : cherchez la référence |
| `appli-*` | Sur le téléphone, **après** une réponse | `appli-reponse` **avec** `réf.` : oui, en 200 ; **sans** `réf.`, ce n'est pas l'API qui a répondu (voir la ligne). Autres `appli-*` : oui, en 200, le serveur a ouvert une session |

Retrouver la ligne d'une référence, sur le serveur de recette (remplacer
`1a2b3c4d` par la référence affichée) :

```bash
for c in $(sudo docker ps --filter label=com.carlys.environment=staging \
             --format '{{.Names}}' | grep api); do
  sudo docker logs "$c" 2>&1 | grep 1a2b3c4d
done
```

Pour un `http-401` dont la phrase est « Google n’a pas pu confirmer ton
identité… », la ligne utile est l'avertissement **« Jeton social refusé »**
que `social-token-verifier.ts` écrit avec la même référence : son champ
`code` (`ERR_JWT_CLAIM_VALIDATION_FAILED`, `ERR_JWT_EXPIRED`…) et son champ
`raison` disent lequel des contrôles a refusé le jeton. Pour « Connexion
impossible avec ce compte. », cette ligne n'existe **pas** : le jeton a été
accepté, c'est le compte qui est refusé (table ci-dessous).

### Table des codes

La liste est **fermée** : chaque code que l'application produit relève
d'une ligne ci-dessous, fixe (`google-10`) ou générique (`google-<code>`), et
`apps/mobile/test/features/authentication/social_auth_failure_test.dart`
vérifie que chacune y figure. La partie variable d'un code (`<statut>`,
`<code>`, `<classe>`) est normalisée : minuscules, chiffres, `_` et `-`,
vingt-quatre caractères au plus, jamais de texte libre venu d'un message.

**SDK Google, avant le serveur**

| Code | Cause | Geste correctif |
| --- | --- | --- |
| `google-config-web` | Le build ne contient pas de client OAuth « Web » (`CARLYS_GOOGLE_SERVER_CLIENT_ID` vide) | Poser la variable de dépôt `CARLYS_GOOGLE_SERVER_CLIENT_ID` (§1.3), puis **reconstruire** l'APK : elle est figée dans le binaire |
| `google-config-ios` | Build iOS sans client OAuth iOS | Poser `CARLYS_GOOGLE_IOS_CLIENT_ID` (§1.3) et reconstruire |
| `google-10` | `DEVELOPER_ERROR` : Google ne reconnaît pas cet APK. Aucun client OAuth **Android** ne porte à la fois le nom de paquet et l'empreinte **SHA-1** de la clé qui l'a signé | Un client OAuth Android **par clé de signature**, tous avec le nom de paquet `com.carlys.carlys_mobile` (un client n'a qu'un champ SHA-1, §1.2) : un pour la clé d'envoi (récapitulatif de `mobile-recette`, étape « Empreintes de la clé de signature »), un pour la clé Play App Signing (Play Console → App signing), un pour la clé de debug au besoin. Ne jamais écraser l'empreinte d'un client existant |
| `google-12500` | `SIGN_IN_FAILED` : Google a refusé de terminer la connexion | Dans l'ordre : écran de consentement OAuth incomplet (nom de l'application, **adresse e-mail d'assistance**) ; écran en mode « Testing » et compte Google absent des « Test users » ; client Android manquant pour l'empreinte SHA-1 de cet APK (souvent confondu avec `google-10`) |
| `google-7` | `NETWORK_ERROR` : les services Google Play n'ont pas joint Google | Réseau du téléphone ; services Google Play à jour |
| `google-4` | `SIGN_IN_REQUIRED` : aucun compte Google utilisable sur l'appareil | Ajouter un compte Google dans les réglages Android, réessayer |
| `google-<statut>` | Tout autre statut `ApiException` des services Google Play (`google-8` : erreur interne, `google-16` : annulé…) | Chercher le statut dans `CommonStatusCodes` / `GoogleSignInStatusCodes` de la documentation Google |
| `google-sign_in_failed` | Échec **sans** statut : l'écran de choix du compte a rendu la main sans résultat | Réessayer ; si ça persiste, mettre à jour les services Google Play |
| `google-exception` | Le greffon n'a pas pu s'initialiser ou obtenir les jetons (message Java dans le journal de l'appareil) | Relancer l'application ; vérifier les services Google Play |
| `google-user_recoverable_auth` | Google exige une action de la personne (réautorisation) et n'a pas pu la présenter | Réessayer, application au premier plan |
| `google-failed_to_recover_auth` | La réautorisation demandée par Google a été refusée ou abandonnée | Réessayer en acceptant l'autorisation |
| `google-status` | Le greffon n'a pas pu oublier le compte précédent (`signOut`, appelé avant chaque demande) | Réessayer ; au besoin, retirer Carlys des « Applications connectées » du compte Google |
| `google-network_error` | Réseau Google, sans statut | Comme `google-7` |
| `google-sans-jeton` | Google a ouvert sa session **sans** jeton d'identité pour Carlys : `CARLYS_GOOGLE_SERVER_CLIENT_ID` n'est pas l'identifiant d'un client de type **Web** (client Android ou iOS collé par erreur) | Mettre l'identifiant du client **« Web application »** dans `CARLYS_GOOGLE_SERVER_CLIENT_ID`, reconstruire |
| `google-plugin` | Le côté natif du greffon n'a **rien répondu** (`channel-error` du canal Pigeon ; `MissingPluginException` hors téléphone). Deux causes : greffon absent du build, **ou** exception Java levée par `GoogleSignInPlugin` hors de son canal d'erreur, que le moteur rattrape en répondant vide : « signIn needs a foreground activity » (l'application est passée en arrière-plan pendant l'appui), « Concurrent operations detected » (deux demandes en même temps). `adb logcat` montre alors « Uncaught exception in binary message listener » et la pile Java | Relancer l'application, réessayer d'un seul appui, application au premier plan. À **chaque** essai : défaut de build, relancer `flutter pub get`, reconstruire ; vérifier qu'aucun réglage R8/ProGuard ne retire le greffon |
| `google-java-<classe>` | Exception Java renvoyée par le canal Pigeon sans code du greffon : seule sa classe est gardée (`google-java-illegal-state` pour `IllegalStateException`), jamais son message | `adb logcat` au moment de l'essai : la pile Java nomme la cause ; transmettre le code |
| `google-<code>` | Tout autre code du canal, normalisé : `google-null-error` (le natif a rendu une valeur vide là où il en fallait une), ou un code qu'une version future du greffon ajouterait | Transmettre le code et la version de l'application ; relancer l'application |
| `google-inattendu` | Toute autre erreur du SDK Google (par exemple « User is no longer signed in. ») | Réessayer ; transmettre le code et le moment exact |

**SDK Apple, avant le serveur**

| Code | Cause | Geste correctif |
| --- | --- | --- |
| `apple-plateforme` | Apple demandé hors iPhone, iPad ou Mac | Aucun : utiliser Google ou l'adresse e-mail |
| `apple-<raison>` | Refus d'Apple : `apple-failed`, `apple-invalid-response`, `apple-not-handled`, `apple-not-interactive`, `apple-unknown` | Capacité **Sign in with Apple** absente de l'App ID ou du projet Xcode (§2) ; identifiant Apple non connecté sur l'appareil |
| `apple-<code>` | Autre erreur du greffon : `apple-not-supported` (iOS trop ancien), `apple-credentials-error`, ou le code brut du canal | Selon le code |
| `apple-sans-jeton` | Apple a autorisé sans jeton d'identité | Réessayer ; vérifier la capacité Sign in with Apple |
| `apple-plugin` | Greffon Apple absent du build (`MissingPluginException` : le greffon Apple parle `MethodChannel`) | Défaut de build : relancer `flutter pub get`, reconstruire |
| `apple-inattendu` | Toute autre erreur du SDK Apple | Réessayer ; transmettre le code |

**Réseau vers Carlys** (aucune réponse HTTP)

| Code | Cause | Geste correctif |
| --- | --- | --- |
| `reseau-delai` | Délai dépassé (connexion 10 s, réponse 20 s) | Réseau lent ou API figée : `curl` du §3 depuis un autre réseau |
| `reseau-connexion` | Connexion refusée ou coupée, nom introuvable | L'adresse figée dans l'APK (`CARLYS_API_BASE_URL`, récapitulatif de `mobile-recette`) est-elle la bonne ? DNS de `api-staging.<domaine>` ; réseau du téléphone |
| `reseau-certificat` | Le certificat TLS de l'API est refusé par le téléphone | Date du téléphone ; certificat du vhost expiré ou incomplet (chaîne intermédiaire) ; Wi-Fi qui intercepte le TLS. Jamais « accepter quand même » |
| `reseau-inconnu` | Requête annulée, ou échec de transport que Dio ne classe pas | Changer de réseau ; transmettre le code |

**Réponse HTTP d'erreur**

| Code | Cause | Geste correctif |
| --- | --- | --- |
| `http-401` | Le serveur a refusé. **La phrase affichée dit lequel des trois refus** (`social-token-verifier.ts`, `social-auth.service.ts`) : voir les trois lignes suivantes | Selon la phrase ; chercher la référence dans les journaux (voir plus haut) |
| ↳ « Google n’a pas pu confirmer ton identité… » (ou Apple) | Le **jeton** est refusé : audience (`GOOGLE_OAUTH_CLIENT_IDS` ne **contient** pas l'identifiant du client **Web** que porte l'APK), horloge du serveur, jeton trop vieux, trousseau du fournisseur injoignable | Chercher l'avertissement **« Jeton social refusé »** avec la référence : ses champs `code` et `raison` disent lequel des contrôles a refusé. Audience : la liste `GOOGLE_OAUTH_CLIENT_IDS` (`printenv` du §1.3) doit **contenir** la valeur de `CARLYS_GOOGLE_SERVER_CLIENT_ID` (elle peut en porter d'autres, le client iOS par exemple) |
| ↳ « Le fournisseur n’a pas transmis d’adresse e-mail vérifiée… » | Le jeton est bon, mais son adresse n'est pas garantie vérifiée : ni rattachement ni création de compte | Aucun geste serveur : se connecter par e-mail. Trace : audit `auth.social_login_refused_unverified_email` |
| ↳ « Connexion impossible avec ce compte. » | Le jeton est bon (**aucune** ligne « Jeton social refusé ») : le compte Carlys de cette adresse est **suspendu ou désactivé**, ou deux premières connexions simultanées se sont croisées au rattachement | Voir le compte dans l'administration ; audit `auth.social_login_blocked` (suspendu) ou `auth.social_attach_conflict` (course : réessayer suffit) |
| `http-403` | **Jamais produit par l'API sur cette route** (aucune garde de `/auth/social` ne lève 403) : c'est un intermédiaire qui a refusé (règle nginx, pare-feu applicatif), d'où l'absence de `réf.`. Sa page d'erreur n'est pas affichée : l'appli dit « n’a pas pu ouvrir ta session » | `/var/log/nginx/error.log` et `access.log` à l'heure de l'essai ; règles `deny` du vhost `api-staging` |
| `http-400`, `http-409`, `http-422` | Requête refusée par la validation du serveur | La phrase est celle du serveur ; chercher la référence |
| `http-429` | Limite des routes d'authentification : **10 requêtes par minute** et par adresse IP | Attendre une minute. Répété : plusieurs testeurs derrière la même IP, ou un client qui boucle |
| `http-503` avec `réf.` | L'API n'a pas d'audience pour ce fournisseur : `GOOGLE_OAUTH_CLIENT_IDS` (ou `APPLE_OAUTH_AUDIENCES`) absent, ou posé sans redéploiement | §1.3 : poser la variable, **redéployer**, vérifier avec `printenv` |
| `http-503` sans `réf.` | nginx : l'API ne répond pas (redémarrage en cours). L'appli le dit comme une panne (« n’a pas pu ouvrir ta session »), jamais « arrive bientôt » : seul le 503 **de l'API** (son enveloppe d'erreur) veut dire « fournisseur non activé » | Réessayer dans une minute |
| `http-500` | Erreur interne de l'API | Chercher la référence : la ligne « Exception HTTP 5xx » ou « Exception non gérée » porte la pile |
| `http-502`, `http-504` | Sans `réf.` : nginx n'a pas joint l'API (conteneur arrêté, refus de démarrage) | `docker compose logs api` dans le projet `carlys_staging` (voir `mise-en-route-serveur.md`) |
| `http-<statut>` | Tout autre statut (`http-404` : adresse d'API fausse dans l'APK, par exemple) | Selon le statut ; la référence, s'il y en a une |

**Après la réponse** (quelque chose a répondu 200)

| Code | Cause | Geste correctif |
| --- | --- | --- |
| `appli-reponse` avec `réf.` | L'API Carlys a répondu (son en-tête `x-request-id` est là), mais sa réponse ne se lit pas : champ absent, type inattendu, JSON tronqué. L'application et l'API ne parlent plus le même contrat | Mettre à jour l'application, ou vérifier que l'API déployée est celle attendue (`/srv/carlys/staging/DEPLOYED`) ; chercher la référence |
| `appli-reponse` sans `réf.` | **Autre chose que l'API** a répondu 200 : page de portail captif (Wi-Fi public), proxy, ou `CARLYS_API_BASE_URL` figée dans l'APK qui pointe sur autre chose que l'API (site, administration). Aucune ligne `/auth/social` dans les journaux de l'API | Réessayer en 4G ; vérifier `CARLYS_API_BASE_URL` dans le récapitulatif de `mobile-recette` : `curl -si <adresse>/health/live \| grep -i x-request-id` doit trouver l'en-tête que l'API pose sur chaque réponse |
| `appli-stockage` | Le trousseau du téléphone (Keystore Android) a refusé d'enregistrer les jetons. La session est aussitôt révoquée | Réessayer ; redémarrer le téléphone ; en dernier recours, vider les données de Carlys |
| `appli-compte` | L'appareil n'a pas pu passer à ce compte (purge des données du compte précédent, ou marqueur de propriétaire, en échec). La session est aussitôt **abandonnée** : révoquée côté serveur, jetons effacés, rien d'ouvert à moitié | Réessayer. Répété : transmettre le code, c'est la base locale qui résiste |
| `appli-inattendu` | Le filet : une erreur que rien d'autre ne classe | Transmettre le code et le moment exact |


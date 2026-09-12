# Builds mobiles — recette et production

Ce document s'adresse à quelqu'un qui **n'a encore rien configuré**. Il dit ce
qu'on peut faire tout de suite sans créer le moindre secret, ce qu'il faut créer
pour aller plus loin, et dans quel ordre.

L'application mobile n'est pas déployée par le serveur : elle est **compilée
puis installée** — sur un téléphone par téléversement direct, ou sur un magasin.
Ce qui la relie au serveur tient dans trois `--dart-define` figés **à la
compilation**. C'est toute la difficulté du mobile : là où une image Docker se
reconfigure au démarrage, un binaire d'application porte son adresse de serveur
gravée dedans.

Le mobile est le **miroir du serveur**, pas un chemin parallèle. Le serveur a
deux workflows — une publication automatique de recette, une publication de
production déclenchée à la main — et une bascule qui exige un geste humain
(`scripts/server/promote.sh`, qui fait recopier le sha). Le mobile a exactement
la même forme, avec le même vocabulaire.

> **Ce qui a disparu.** Un APK de **démonstration** était publié jusqu'ici sur
> une release `demo-latest` : `CARLYS_FLAVOR=demo`, API sur `localhost`, données
> intégrées. Il faisait visiter l'interface et ne prouvait rien du système réel —
> il ne parlait à aucun serveur. Il est remplacé par la vraie application de
> recette, qui vise le vrai serveur de recette. Le mode démo existe toujours dans
> le code ; ce qui a cessé, c'est sa construction automatique.

---

## 1. Les deux chemins, et ce qui les sépare

```
    poussée sur la branche (ou Run workflow)
                     │
                     ▼
  ┌────────────────────────────────────────────┐
  │ mobile-recette        AUTOMATIQUE          │
  │ entrée « sha » facultative                 │
  │ CARLYS_FLAVOR=staging                      │
  │   → api-staging.DOMAINE                    │
  └──────────────────┬─────────────────────────┘
                     │  .apk installable, toujours
                     │  .aab seulement si signature posée
                     │  .ipa sur demande (job macOS, §10)
                     ▼
        INSTALLER sur un téléphone, OUVRIR,
        essayer vraiment — puis noter le sha
                     │
                     ▼
  ┌────────────────────────────────────────────┐
  │ mobile-production     À LA MAIN, SEULEMENT │
  │ entrée « sha » OBLIGATOIRE                 │
  ├────────────────────────────────────────────┤
  │ job 1 · contrôles — sans attente           │
  │    · l'approbation est-elle armée ?        │
  │    · ce sha existe-t-il en recette ?       │
  │    · textes légaux complets ?              │
  │    · CARLYS_DOMAIN bien formée ?           │
  └──────────────────┬─────────────────────────┘
                     │
              EN PAUSE — « Waiting »
                     │
     un humain clique « Approve and deploy »
                     │
                     ▼
  ┌────────────────────────────────────────────┐
  │ job 2 · construire                         │
  │ CARLYS_FLAVOR=production                   │
  │   → api.DOMAINE                            │
  │ keystore déballé · .aab SIGNÉ · apk de     │
  │ vérification · symboles · keystore effacé  │
  └──────────────────┬─────────────────────────┘
                     │
                     ▼
        Play Console — téléversement à la main
```

Les deux gardes qui font pause en tête du job 1 — l'approbation armée, le sha
déjà construit en recette — sont volontairement **avant** l'approbation : voir
§6.3.

Ce qui sépare les deux chemins, ligne à ligne :

| | Recette | Production |
| --- | --- | --- |
| Déclenchement | poussée sur la branche, ou à la main | **à la main uniquement** — aucune poussée ne peut la déclencher |
| Dépôt sur un magasin | **jamais sur poussée** — case « publier » d'une exécution manuelle, uniquement | jamais : l'artefact se dépose à la main |
| Entrée `sha` | facultative (vide = tête de la branche) | **obligatoire** |
| `CARLYS_FLAVOR` | `staging` | `production` |
| Adresses visées | `api-staging.DOMAINE`, `app-staging.DOMAINE` | `api.DOMAINE`, `app.DOMAINE` |
| Approbation humaine | non | **oui** — environnement GitHub à « required reviewers » |
| Textes légaux complets exigés | non | **oui** — refus tant qu'un `[À COMPLÉTER : …]` subsiste |
| Le commit doit déjà exister en recette | — | **oui** (règle « build once ») |
| `.apk` produit | toujours, sans aucun secret | oui, mais **de vérification seulement** |
| `.aab` produit | seulement si la signature est configurée | **toujours** — sinon le workflow échoue |
| `.ipa` produit | **sur demande** (variable `CARLYS_IOS_BUILDS`, ou case « ios »), secrets Apple obligatoires — §10 | non : la production n'a pas de job iOS (§10.7) |
| Dépôt sur le magasin | piste interne Play et TestFlight — **case « publier » uniquement**, secrets posés | à la main |
| Où va l'artefact | onglet Actions de l'exécution | onglet Actions de l'exécution |

**Pourquoi la production ne redéploie pas les octets de la recette.** Côté
serveur, la règle est « build once » au sens strict : la production redéploie
exactement l'image éprouvée en recette. En mobile, c'est impossible, et ce n'est
pas une entorse : `--dart-define` est résolu à la compilation, donc un binaire
qui vise `api-staging` ne peut pas viser `api`. C'est la même raison qui oblige à
reconstruire l'image admin en production, où `NEXT_PUBLIC_API_BASE_URL` est
inlinée dans le JavaScript du navigateur. La règle est donc tenue sous une forme
dégradée mais explicite : **on ne construit en production que des commits déjà
construits en recette**, et le workflow le vérifie avant de déranger qui que ce
soit.

---

## 2. De quoi a-t-on besoin, selon la cible

C'est le tableau le plus important de ce document. Les trois lignes n'ont ni les
mêmes exigences ni les mêmes délais, et les confondre coûte cher.

| Cible | Format | Signature | Secret à créer | Faisable aujourd'hui ? |
| --- | --- | --- | --- | --- |
| **Téléphone de test** (le vôtre, celui d'un testeur) | `.apk` | clé de **debug**, et c'est sans conséquence | **aucun** | **oui, tout de suite** |
| **Play Store, Galaxy Store** | `.aab` | **keystore obligatoire** | 4 secrets (§4), + 1 pour la piste interne (§4.6) | oui, une fois le keystore créé |
| **TestFlight, App Store (iOS)** | `.ipa` | **certificat Apple Distribution + profil App Store** | 3 secrets (§10), + 3 pour TestFlight | oui, **sur demande** — runner macOS de GitHub, dix fois le prix d'une minute Linux |

Trois choses à ne jamais mélanger :

- **Un `.apk` signé en debug s'installe parfaitement** sur un téléphone par
  téléversement direct. Android l'accepte hors magasin ; la clé de debug ne le
  gêne en rien. C'est ce qui rend la recette possible **aujourd'hui**, sans
  qu'aucun secret n'existe.
- **Un `.aab` signé en debug est refusé par la Play Console.** Et il est refusé
  au *téléversement*, c'est-à-dire à la toute fin, après le build et après
  l'approbation. C'est pourquoi le workflow de recette préfère **ne produire
  aucun `.aab`** plutôt qu'un binaire dont on découvrirait le vice au pire
  moment.
- **Un `.aab` ne s'installe pas sur un téléphone.** C'est un format
  intermédiaire, que le magasin découpe lui-même en APK par appareil. Il est
  donc impossible de *lancer* un `.aab` pour vérifier qu'il fonctionne — d'où
  l'APK de vérification que produit le workflow de production, bâti sur le même
  code, les mêmes `--dart-define` et la **même clé**.

**iOS se construit sur demande, jamais par défaut.** Apple exige Xcode, donc
macOS : ni le serveur ni les runners Linux ne peuvent produire un `.ipa`. Le
workflow de recette porte un **second job**, sur `macos-latest`, qui ne tourne
que si on le lui demande — variable de dépôt `CARLYS_IOS_BUILDS=oui` pour
chaque poussée, ou case « ios » de **Run workflow** pour une fois. La raison est
le prix : une minute de runner macOS est facturée **dix fois** une minute de
runner Linux sur un dépôt privé. Ce qu'il faut créer chez Apple, et comment le
job vérifie chaque pièce avant de compiler, est au §10.

---

## 3. Aujourd'hui, sans rien configurer : la recette

### 3.1 La seule chose à poser : `CARLYS_DOMAIN`

Les deux workflows dérivent leurs adresses de cette **variable de dépôt** (pas
un secret : ce n'est pas une valeur sensible).

> Settings → Secrets and variables → **Actions** → onglet **Variables** →
> **New repository variable**
>
> - **Nom** : `CARLYS_DOMAIN`
> - **Valeur** : le domaine **nu**, par exemple `carlys.example`

**Le domaine nu, et rien d'autre.** La valeur est concaténée telle quelle
derrière un sous-domaine : `https://api-staging.$CARLYS_DOMAIN`. Le réflexe
naturel est de copier l'adresse du site, schéma compris — et
`https://carlys.example` produit alors littéralement
`https://api-staging.https://carlys.example`, figée dans le binaire. Rien en aval
ne rattrape ça : `--dart-define` accepte n'importe quelle chaîne, le build
réussit, l'application démarre et n'atteint jamais l'API. C'est pourquoi les deux
workflows **valident la forme** de la variable, et pas seulement sa présence : ils
refusent un schéma, une barre oblique finale, un port, un espace, un caractère
interdit. Sont donc rejetés `https://carlys.example`, `carlys.example/` et
`carlys.example:443`.

Un avertissement — pas un refus — est émis si la valeur commence par l'un des six
sous-domaines que le dépôt ajoute lui-même (`api.`, `app.`, `media.`, et leurs
variantes `-staging`).

### 3.2 La marche à suivre

1. **Pousser** sur `development` (ou `production`). Le workflow
   `mobile-recette` part tout seul dès qu'un fichier d'`apps/mobile/` bouge (ou
   les deux scripts qui portent l'identité Android de l'application). Le job
   iOS, lui, ne part qu'à la demande (§10.5).
2. **Ouvrir l'onglet Actions**, l'exécution la plus récente. Compter une
   vingtaine de minutes à froid, moins ensuite grâce aux caches Dart et Gradle.
3. **Télécharger l'artefact** en bas de la page d'exécution — ou passer par le
   **lien bêta permanent** (§3.4), plus simple pour un téléphone. Le nom de
   l'artefact porte les douze premiers caractères du sha construit — ce n'est
   pas décoratif : c'est ce sha qu'il faudra renseigner plus tard pour la
   production. Le récapitulatif de l'exécution (onglet Summary) fait foi sur
   le contenu exact de l'artefact.
4. **Décompresser** le `.zip` que GitHub enveloppe autour de tout artefact, et
   transférer le `.apk` sur le téléphone — câble, messagerie, stockage en ligne,
   peu importe.
5. **Installer.** Android demandera d'autoriser l'installation depuis
   l'application qui ouvre le fichier (« Installer des applications inconnues »).
   C'est normal et sans rapport avec la signature.
6. **Ouvrir l'application, et s'en servir.** Se connecter, faire une séance,
   synchroniser. Cette étape n'est pas une formalité : voir §3.3.

### 3.3 Pourquoi il faut LANCER l'artefact, toujours

`AppEnvironment.assertUsable()`
(`apps/mobile/lib/app/environment/app_environment.dart`) refuse de démarrer, en
`staging` comme en `production`, si `CARLYS_API_BASE_URL` **ou**
`CARLYS_PUBLIC_WEB_BASE_URL` manque ou pointe en local (`localhost`,
`127.0.0.1`, et `10.0.2.2`, la boucle locale de l'émulateur Android, sont traités
pareil).

Ce filet est excellent, mais il s'exerce **au lancement, pas à la compilation**.
Le build réussit, l'artefact se télécharge, rien ne signale quoi que ce soit — et
c'est la première ouverture qui échoue. Un artefact qu'on dépose sans l'avoir
ouvert une fois est un artefact dont **le premier lancement réel sera celui d'un
testeur, ou d'un utilisateur**.

Le mode d'échec qu'on évite ainsi est particulièrement sournois pour l'API : une
application dont `CARLYS_API_BASE_URL` est resté sur `localhost:3000` se lance,
affiche son écran d'accueil, et envoie chaque appel réseau vers une adresse qui
n'existe pas sur un téléphone — qu'Android bloque de toute façon en release,
puisqu'elle est en clair. L'application paraît « lente », puis « hors ligne », et
aucun message ne nomme la cause. Le lien légal mort, au moins, se voit à l'œil ;
celui-ci ne se voit qu'au support.

Une dernière remarque, qui compte : `CARLYS_FLAVOR` n'est **pas** contrôlé. Une
valeur inconnue ne casse rien, elle retombe silencieusement sur `development`.
Les workflows l'écrivent correctement ; c'est un point d'attention si vous
compilez à la main.

### 3.4 Le lien bêta permanent

Chaque build Android de la tête de `development` met aussi à jour la release
**`beta`** du dépôt, dont l'unique APK garde un nom stable. Le lien ne change
donc jamais :

```
https://github.com/mimiflo/Carlys/releases/download/beta/carlys-beta.apk
```

C'est le chemin le plus court vers un téléphone : ouvrir ce lien, installer,
c'est tout — pas d'onglet Actions, pas de zip. La page de la release dit quel
commit et quel versionCode il porte ; le tag `beta` suit le commit construit.

**La limite, dite franchement : le dépôt est privé.** Ce lien n'est servi
qu'aux comptes GitHub ayant accès au dépôt — collaborateurs et vous-même. Un
testeur extérieur tombera sur une page 404. Pour lui, deux chemins :

- **le bon, à terme** : la piste interne Play (§4.6) — le lien d'adhésion
  Play s'envoie à n'importe qui, sans compte GitHub, et les mises à jour
  arrivent toutes seules par le Play Store ;
- **en attendant** : télécharger l'APK vous-même via le lien ci-dessus et le
  transmettre (messagerie, stockage partagé) — l'APK s'installe tel quel.
  Servir ce fichier publiquement depuis le serveur de recette est faisable
  proprement si le besoin se confirme ; il n'est pas construit aujourd'hui.

---

## 4. Créer le keystore Android

Le keystore n'est nécessaire que pour les **magasins**. Tant que vous installez
des `.apk` sur des téléphones de test, cette section peut attendre.

### 4.1 Pourquoi il ne peut pas vivre dans le dépôt

Deux raisons, et la seconde est décisive.

D'abord, `apps/mobile/android/` **n'est pas versionné** :
`scripts/bootstrap_mobile.sh` le régénère à la demande. Un keystore et sa
`signingConfig` déposés là seraient écrasés au prochain bootstrap — ils ne
survivraient à personne.

Ensuite, et surtout : **une clé de signature est un secret**, au sens le plus
fort. Qui la détient peut publier une contrefaçon de votre application, qu'Android
acceptera comme une mise à jour légitime. Elle ne va pas dans un dépôt, même
privé.

La clé ne peut donc venir que de **secrets GitHub**, déballés dans le runner le
temps du build et effacés ensuite. C'est ce que font les deux workflows.

### 4.2 La commande

Sur votre poste, dans un répertoire **hors du dépôt** :

```bash
keytool -genkeypair -v \
  -keystore carlys-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`keytool` fait partie du JDK ; si la commande est introuvable, elle est dans
`$JAVA_HOME/bin/`.

Ce que la commande demande ensuite :

- **un mot de passe de magasin** (le keystore lui-même) ;
- votre nom, votre organisation, votre ville, votre pays — ces valeurs
  apparaissent dans le certificat, elles ne sont ni vérifiées ni sensibles ;
- **un mot de passe de clé**. Le proposer identique à celui du magasin est
  courant et accepté ; les deux secrets sont alors simplement égaux.

`-validity 10000` fait environ 27 ans. Ce n'est pas de la superstition : Google
Play exige un certificat valide **au moins jusqu'au 22 octobre 2033**, et une clé
expirée interdit toute mise à jour aussi sûrement qu'une clé perdue.

`-alias upload` nomme la clé **à l'intérieur** du magasin. Un keystore peut en
contenir plusieurs ; c'est cet alias que le secret `ANDROID_KEY_ALIAS` désigne.

Un JDK récent produit un magasin au format PKCS #12 même si le fichier porte
l'extension `.jks`, et le signale parfois par un avertissement de migration.
**C'est sans conséquence** : Gradle lit les deux formats, et les workflows n'en
supposent aucun. Ne relancez pas la commande à cause de ce message.

### 4.3 L'encoder pour en faire un secret

Un secret GitHub est du texte : le `.jks` étant binaire, il faut l'encoder.

```bash
base64 -w0 carlys-release.jks
```

`-w0` (zéro retour à la ligne) n'est pas un détail : sans lui, `base64` coupe sa
sortie tous les 76 caractères, et un copier-coller partiel produit une valeur
tronquée — que `base64 -d` accepte sans broncher, en rendant un fichier corrompu.
Sur macOS, où `base64` ignore `-w`, utiliser `base64 -i carlys-release.jks | tr -d '\n'`.

Coller **toute** la sortie, d'un bloc, dans le secret.

### 4.4 Les quatre secrets

Ils vont **ensemble ou pas du tout** — même règle que les quatre valeurs Firebase,
et pour la même raison : une configuration à moitié posée produit un artefact qui
a l'air correct et ne l'est pas. Les deux workflows vérifient les quatre d'un
coup et disent lequel manque, sans jamais afficher la moindre valeur.

| Secret | Rôle | Comment l'obtenir |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64` | le fichier `.jks` lui-même, encodé | `base64 -w0 carlys-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du **magasin** | celui saisi en premier à la création |
| `ANDROID_KEY_ALIAS` | nom de la clé dans le magasin | `upload` avec la commande ci-dessus |
| `ANDROID_KEY_PASSWORD` | mot de passe de la **clé** | celui saisi en second |

### 4.5 Où les poser — et le compromis à faire en connaissance de cause

GitHub offre deux emplacements, et ils n'ont pas la même portée.

- **Secrets de dépôt** (Settings → Secrets and variables → Actions → Secrets) :
  lisibles par **toutes** les exécutions du dépôt, y compris les builds de
  recette.
- **Secrets d'environnement** (Settings → Environments → `mobile-production` →
  Environment secrets) : lisibles **seulement** par un job qui réclame cet
  environnement — donc, ici, seulement par une exécution **déjà approuvée par un
  humain**.

La clé de signature a sa place dans le second cas. Le revers se dit franchement :
le workflow de recette, lui, ne les verra pas, et ne produira donc **pas** de
`.aab`. C'est son cas nominal, pas une panne — la recette livre l'`.apk`, qui
suffit à éprouver l'application.

Le point qui décide, si vous hésitez : **la Play Console impose la même clé de
téléversement à toutes les pistes** d'une application, piste interne comprise. Si
vous n'avez qu'une clé et que vous la voulez gardée derrière l'approbation de
production, ne posez pas ces secrets au niveau du dépôt. Si vous avez besoin de
déposer des builds de recette sur la piste interne de Play, il faut les poser au
niveau du dépôt — et accepter que toute exécution du dépôt puisse les lire.

Le prix du choix « environnement » est visible au moment de l'usage : le job de
contrôles ne peut pas vérifier la présence des secrets à l'avance, l'échec arrive
donc quelques secondes **après** l'approbation. C'est le bon échange — mieux vaut
un aller-retour qu'une clé de signature accessible à n'importe quelle exécution.

### 4.6 La piste interne Play : le bouton « Publier Carlys Staging Beta »

Un cinquième secret, facultatif, permet à une exécution de déposer le `.aab`
de recette sur la **piste interne** de la Play Console :
`PLAY_SERVICE_ACCOUNT_JSON`, le JSON d'un compte de service Google Cloud invité
dans la Play Console (Utilisateurs et autorisations → Inviter → le compte de
service, droit « Publier sur les pistes de test »). Il suppose les quatre secrets
de signature au niveau du **dépôt** (§4.5).

**Le secret ne suffit pas : rien ne part sur une poussée.** Le dépôt vers un
magasin — piste interne Play comme TestFlight — n'a lieu que sur une exécution
demandée à la main avec la case **publier** :

> Actions → `mobile-recette` → **Run workflow** → cocher **publier** — et
> aussi **ios** si le build TestFlight est du voyage (la case publier seule ne
> lance pas le job iOS : sans compte Apple, une publication Android doit
> pouvoir finir verte) → Run.

La présence d'un secret dit qu'on *peut* publier, pas qu'on *veut* : décider,
c'est cliquer. Une poussée ordinaire construit et archive les artefacts signés,
prêts, et n'envoie rien nulle part. Et le contraire vaut aussi : une exécution
**publier** à qui il manque un secret nécessaire au dépôt demandé **échoue en
rouge** plutôt que de réussir sans avoir rien déposé.

Trois choses encore, apprises avant qu'elles ne coûtent :

- **Le `versionCode`** est le numéro d'exécution du workflow — jamais deux fois
  le même, il ne recule pas. La production compte à part : son défaut est
  décalé de +100000 pour rester toujours au-dessus de la recette, la Play
  Console refusant tout `versionCode` déjà téléversé, toutes pistes confondues.
- **Le tout premier dépôt** d'une application neuve peut être refusé par l'API
  avant que la fiche ne soit complète : si l'exécution « publier » échoue au
  téléversement sur une application jamais déposée, prendre l'artefact `.aab`
  de cette même exécution et le déposer une fois à la main dans la Play
  Console, puis relancer — les suivants passeront par l'API.
- **Les testeurs ne trouvent pas la piste interne tout seuls** : la Play
  Console (Test interne → Testeurs) donne un **lien d'adhésion** à leur
  envoyer ; sans l'avoir ouvert, un testeur ne voit rien dans le Play Store.

---

## 5. L'avertissement qui compte : perdre le keystore

**Un keystore perdu rend toute mise à jour de l'application impossible.**

Ce n'est pas une gêne, c'est un mur. Android identifie une application par son
`applicationId` **et** par le certificat qui la signe. Une mise à jour signée par
une autre clé n'est pas une mise à jour : c'est une autre application, et le
système la refuse. Il n'existe aucune procédure de récupération, aucun support à
contacter, aucun contournement.

Ce que coûte concrètement cette perte : il faut **republier sous une nouvelle
identité** — un nouvel `applicationId`, une nouvelle fiche, une nouvelle URL. Et
avec elle, on perd :

- **toutes les installations existantes.** Les utilisateurs ne reçoivent pas de
  mise à jour : ils gardent une version figée pour toujours, et doivent
  découvrir, trouver et installer la nouvelle application à la main ;
- **tous les avis et toutes les notes.** Ils sont attachés à la fiche, qui
  disparaît. Une application à 4,6 étoiles sur mille avis repart à zéro ;
- **le référencement** que la fiche avait acquis, et les liens qui pointaient
  vers elle.

**Où le sauvegarder :**

- dans un **gestionnaire de mots de passe** ou un coffre-fort d'entreprise
  (1Password, Bitwarden, Vault…), avec le fichier `.jks` **et** les trois valeurs
  qui l'accompagnent — un keystore sans son mot de passe est aussi perdu qu'un
  keystore absent ;
- **au moins deux copies, en deux endroits distincts**, dont une hors de la
  machine de développement. Un disque meurt, un portable se vole ;
- **jamais** dans le dépôt, jamais dans un partage de fichiers ouvert à
  l'équipe, jamais dans un fil de discussion.

Les secrets GitHub **ne sont pas une sauvegarde** : ils sont chiffrés en écriture
seule, personne — pas même vous — ne peut relire leur valeur. Poser
`ANDROID_KEYSTORE_BASE64` puis effacer le `.jks` de votre poste, c'est perdre la
clé.

> **Une atténuation, et sa limite exacte.** Si vous activez **Play App Signing**
> (le défaut pour toute nouvelle application sur Play), Google détient la vraie
> clé de signature et vous ne détenez qu'une **clé de téléversement**. Perdre
> celle-ci se répare : le support Play peut la réinitialiser. Cela ne vaut que
> pour Play : sur le **Galaxy Store** et pour toute distribution directe d'APK,
> il n'y a aucun filet, et le paragraphe ci-dessus s'applique intégralement.

---

## 6. Armer le OUI humain

Sans cette section, le workflow de production **s'exécuterait sans rien
demander**. C'est le point le plus important après le keystore.

### 6.1 Créer l'environnement

> Settings → **Environments** → **New environment**
>
> 1. **Nom** : `mobile-production` — exactement ce nom.
> 2. Cocher **Required reviewers**.
> 3. Ajouter **au moins une personne** (vous-même convient).
> 4. **Save protection rules**.

Le nom compte : c'est celui que le job de construction réclame. Un environnement
nommé autrement ne protège rien.

### 6.2 Le piège : un environnement sans reviewer ne demande rien

Créer l'environnement **ne suffit pas**. Un environnement GitHub sans règle
`Required reviewers` est un environnement qui laisse passer : le job s'exécute
immédiatement, sans pause, sans notification, sans qu'aucune erreur ne soit
signalée nulle part. Le workflow porterait le nom d'une garde qui n'existe pas.

C'est pourquoi le workflow **interroge l'API GitHub en toute première étape**
pour vérifier que la règle existe réellement, et **échoue** dans les deux cas où
personne ne demanderait rien : l'environnement n'existe pas, ou il existe sans
reviewer. Le workflow le dit, il ne le suppose pas. Un troisième cas — l'API
illisible — n'est pas une preuve d'absence : il produit un avertissement bruyant
et laisse la protection native faire son office, s'il y en a une.

### 6.3 Ce que voit l'approbateur, et pourquoi les gardes passent avant

L'approbation d'un environnement met le job en pause **avant sa première étape**.
Mettre les vérifications dans le job protégé obligerait donc à approuver
d'abord, puis à découvrir que les textes légaux ne sont pas prêts — une
approbation dépensée pour rien.

Les gardes vivent donc dans un **premier job non protégé**. L'humain n'est
sollicité qu'une fois qu'elles sont vertes, et le récapitulatif de ce premier job
lui dit sur quoi il se prononce : le sha, le message du commit, le versionCode
retenu et les trois `--dart-define` exacts qui seront figés dans le binaire.

Le pendant côté serveur est `scripts/server/promote.sh`, qui ne demande pas de
taper « oui » mais de **recopier le sha** : une frappe réflexe ne doit pas suffire
à basculer la production. Les deux gestes ont la même intention.

---

## 7. La marche à suivre, de bout en bout

Une fois `CARLYS_DOMAIN`, les quatre secrets et l'environnement en place :

1. **Pousser** le commit. `mobile-recette` construit tout seul.
2. **Récupérer l'artefact de recette** dans l'onglet Actions, décompresser,
   **installer l'`.apk`** sur un téléphone.
3. **Éprouver l'application pour de vrai** : ouvrir, se connecter, faire une
   séance, la synchroniser, vérifier que les deux liens légaux des réglages
   s'ouvrent. C'est la seule étape qui exécute `assertUsable()`.
4. **Noter le sha** de ce build — les douze caractères que porte le nom de
   l'artefact. C'est lui, et lui seul, qu'on promeut.
5. Si les textes légaux ne sont pas encore écrits : **les compléter**
   (`docs/legal/privacy.md`, `docs/legal/terms.md`), pousser, et reprendre au
   point 1 avec le nouveau sha. Voir §9 du guide serveur — la garde est la même
   des deux côtés, et elle ne se contourne pas.
6. **Lancer la production** : Actions → `mobile-production` → **Run workflow** →
   renseigner le **sha** (obligatoire). Laisser `build_number` vide sauf pour
   reprendre la numérotation d'un dépôt Play existant : par défaut, le workflow
   utilise `100000 + son numéro d'exécution` — le décalage garde la production
   au-dessus des `versionCode` que la recette dépose sur la piste interne avec
   son propre compteur, la Play Console refusant tout numéro déjà téléversé,
   toutes pistes confondues.
7. **Le job de contrôles s'exécute** en quelques minutes. S'il échoue, il dit
   quoi faire — voir §9 ci-dessous.
8. **Approuver.** L'exécution est affichée « Waiting » ; le reviewer reçoit une
   notification, ouvre l'exécution, lit le récapitulatif des contrôles, clique
   **Approve and deploy**.
9. **Récupérer l'artefact de production** : il contient le `.aab` à téléverser,
   un `.apk` de vérification (même code, même clé) et les symboles de débogage.
10. **Lancer l'APK de vérification une fois** sur un téléphone, pour la raison
    du §3.3 : un `.aab` ne s'installe pas, il ne peut donc pas être essayé.
11. **Téléverser le `.aab`** dans la Play Console, puis les symboles pour que les
    rapports de plantage soient lisibles.
12. **Basculer le serveur sur le même commit**, si ce n'est pas déjà fait :
    `sudo /srv/carlys/repo/scripts/server/promote.sh`. Le workflow mobile ne
    touche à rien côté serveur — et l'application publiée appelle `api.DOMAINE`.

Le workflow vérifie que la signature du bundle est **bien la vôtre** avant de
livrer l'artefact : il compare l'empreinte SHA-256 du certificat qui a signé le
bundle à celle de l'alias du keystore, et échoue si elles diffèrent. Le mode
d'échec ainsi fermé est précis et silencieux — le gabarit Flutter signe la
release avec la clé de debug, un `.aab` ainsi signé se construit et s'archive
parfaitement, et n'est rejeté qu'au téléversement, après l'approbation.
L'empreinte est reportée dans le récapitulatif : ce n'est pas un secret, la Play
Console l'affiche aussi, et c'est à elle qu'il faut la confronter.

---

## 8. Ce qui reste manuel, et pourquoi

Rien de ce qui suit n'est automatisable depuis ce dépôt. Ce sont des gestes de
magasin, et ils engagent.

- **Les comptes.** Google Play Console (frais unique), Samsung Seller, Apple
  Developer (abonnement annuel). Création, vérification d'identité, coordonnées
  bancaires — plusieurs jours de délai possibles pour la vérification.
- **La fiche du magasin.** Description courte et longue, captures d'écran par
  format d'appareil, icône 512×512, bannière 1024×500, classification du contenu,
  formulaire de sécurité des données. Aucun de ces éléments n'est dans le dépôt,
  et ils sont exigés avant la première soumission.
- **L'URL de politique de confidentialité doit être EN LIGNE.** La garde des
  textes légaux vérifie qu'ils sont **écrits** ; elle ne peut pas vérifier qu'ils
  sont **servis**. Un examinateur ouvrira `https://app.DOMAINE/privacy` — la page
  doit répondre. C'est l'application web qui la sert : **§9 du guide serveur doit
  être fait avant toute soumission en production**.
- **Les pièces Apple.** Le certificat Apple Distribution, le profil de
  provisionnement et la clé API App Store Connect se créent sur
  developer.apple.com et App Store Connect, à la main, et **se renouvellent**
  (certificat et profil valent un an). Leur usage, lui, est automatisé : §10.
- **Les testeurs.** Inscrire les testeurs internes (jusqu'à cent, membres de
  l'équipe App Store Connect) et externes (jusqu'à dix mille, après un examen
  Beta App Review) se fait dans App Store Connect → TestFlight ; côté Play,
  la liste des testeurs de la piste interne se tient dans la Play Console.
- **Le versionCode.** Play refuse un versionCode déjà téléversé, toutes pistes
  confondues. La recette utilise son numéro d'exécution, la production
  `100000 +` le sien — deux plages qui ne se croisent pas. Si vous reprenez un
  dépôt existant dont la numérotation est plus haute, renseignez `build_number`
  au premier passage.
- **La version affichée (versionName).** C'est le `version:` de
  `apps/mobile/pubspec.yaml` (aujourd'hui `0.1.0`) : la CI ne passe jamais
  `--build-name`, une version marketing se décide par un commit qui monte
  cette ligne. Les récapitulatifs d'exécution l'affichent ; tant qu'elle ne
  bouge pas, tous les builds — recette comme production — se présentent en
  `0.1.0` et seuls leurs numéros de build les distinguent.
- **Les notifications push.** Les quatre valeurs Firebase ne sont pas injectées
  par les workflows. Leur absence désactive proprement le push, le reste de
  l'application vivant normalement — les ajouter est un geste délibéré, décrit au
  §8 du guide serveur. Attention : `google-services.json` décrit l'application
  **Android**, l'équivalent iOS est `GoogleService-Info.plist` et son `appId`
  diffère. Prévoyez deux fichiers.

---

## 9. Quand ça ne marche pas

Les messages d'erreur des workflows sont écrits pour être suffisants à eux
seuls. Voici ceux qu'on rencontre en pratique — et un cas qui n'est pas une
erreur : un bundle ou un `.ipa` construit mais **non téléversé** signifie
presque toujours que l'exécution n'avait pas la case « publier » (§4.6), et le
récapitulatif le dit.

| Ce que dit l'exécution | Ce qui se passe | Quoi faire |
| --- | --- | --- |
| « Variable de dépôt `CARLYS_DOMAIN` absente » ou « mal formée » | la variable manque, ou porte un schéma / une barre / un port | §3.1 — le domaine **nu**, rien d'autre |
| « Bundle de magasin NON produit » (avertissement, recette) | les quatre secrets de signature ne sont pas visibles par ce workflow | c'est le **cas nominal** si vous les avez posés sur l'environnement (§4.5). L'`.apk` est livré normalement |
| « Ce commit n'a pas été construit en recette » | la règle « build once » : aucun artefact de recette ne porte ce sha | relancer la recette **sur ce sha** (champ « sha » du Run workflow), l'installer, l'essayer, revenir |
| « L'artefact de recette a expiré » | GitHub supprime les artefacts après la rétention du dépôt (90 jours par défaut) | relancer la recette sur ce sha — et en profiter pour ré-essayer un commit vieux de plusieurs mois — ou promouvoir un commit plus récent |
| « Les textes légaux ne sont pas prêts pour la production » | un `[À COMPLÉTER : …]` subsiste dans `docs/legal/` | les compléter, pousser, reconstruire en recette, relancer sur le nouveau sha. Aucun contournement |
| « Environnement mobile-production inexistant » ou « … sans reviewer » | l'approbation humaine n'est pas armée | §6 |
| « Secrets de signature absents » (après approbation) | les quatre secrets ne sont pas sur l'environnement | §4.4 et §4.5 |
| « Signature iOS impossible — secret(s) absent(s) » | le job iOS a été demandé sans ses trois secrets | §10.3 — ou retirer `CARLYS_IOS_BUILDS` |
| « Aucun certificat de DISTRIBUTION valide » | certificat de développement, expiré, ou `.p12` sans clé privée | §10.2 |
| « Le profil n'embarque aucun des certificats importés » | profil engendré pour un autre certificat (renouvelé sans régénérer le profil) | §10.1, régénérer le profil |
| « Le profil ne vise pas cette application » | l'App ID du profil n'est pas celui que `flutter create` engendre | enregistrer l'App ID que le message cite, refaire le profil |
| « Profil Ad Hoc ou Development — pas App Store » | mauvais type de profil | §10.1 — type Distribution → App Store Connect |

Deux limites à connaître, dites franchement plutôt que découvertes :

- La garde « build once » prouve que le commit a été **fabriqué** en recette, pas
  qu'un humain l'a **installé et essayé**. Exactement comme, côté serveur,
  vérifier qu'une image existe ne prouve pas qu'on l'a fait tourner. C'est
  l'approbation humaine qui couvre ce trou — d'où l'insistance du §7, point 3.
- Elle peut refuser un commit ancien dont l'artefact a **expiré**, alors qu'il
  avait bel et bien été construit. C'est un faux refus, jamais un faux accord :
  elle se trompe du bon côté.

---

## 10. iOS — certificat, profil, TestFlight

Le job « Application de recette (iOS) » de `mobile-recette` produit un `.ipa`
signé pour App Store Connect et, si une clé API est posée, le dépose sur
TestFlight. Il tourne sur un runner macOS de GitHub — le seul endroit du dépôt
où Xcode existe — et **seulement sur demande** (§10.5).

Une chose à savoir avant de commencer, dite franchement : ce job a été écrit et
relu depuis un environnement **sans macOS ni SDK Flutter**. Sa syntaxe est
validée, ses fragments de shell ont été exécutés un à un avec des entrées
d'essai, ses vérifications de certificat et de profil sont celles de la
documentation GitHub et Flutter — mais **sa première exécution complète sera la
vôtre**. Si elle échoue, le journal de l'étape fautive dit quoi faire ; si le
message ne suffit pas, c'est un défaut du workflow à corriger, pas à contourner.

### 10.1 Ce qu'il faut chez Apple, dans l'ordre

1. **Un compte Apple Developer** (abonnement annuel), sur developer.apple.com.
   La vérification d'identité peut prendre plusieurs jours.
2. **L'App ID** : Certificates, Identifiers & Profiles → Identifiers → « + » →
   App IDs → type App → **Explicit** Bundle ID. La valeur est celle
   qu'engendre `flutter create --org com.carlys --project-name carlys_mobile`,
   qui met le nom du projet en camelCase sur iOS : `com.carlys.carlysMobile`
   (Android, lui, reçoit `com.carlys.carlys_mobile`). **Le job l'affiche** à
   l'étape « Identifiant de bundle », avant tout contrôle de secret, et le
   cite dans son message d'échec : c'est lui qui fait foi. Aucune capacité
   (Push, etc.) n'est requise pour la recette.
3. **Le certificat** : Certificates → « + » → **Apple Distribution**. Il exige
   une demande de signature (CSR) créée sur votre Mac avec Trousseaux d'accès
   → Assistant de certification → Demander un certificat à une autorité de
   certification → « Enregistrée sur le disque ». Téléchargez le `.cer` produit
   et ouvrez-le : il rejoint le trousseau **à côté de la clé privée** que la
   demande a créée. Un certificat **Apple Development** ne convient pas — il
   ne signe ni pour TestFlight ni pour l'App Store, et le job le refuse.
4. **Le profil** : Profiles → « + » → Distribution → **App Store Connect** →
   l'App ID du point 2 → le certificat du point 3 → un nom (par exemple
   « Carlys App Store ») → télécharger le `.mobileprovision`. Le profil
   **embarque** le certificat : si vous renouvelez le certificat, régénérez le
   profil, sinon le job refusera la paire.
5. **La fiche App Store Connect** : appstoreconnect.apple.com → Apps → « + »
   → même Bundle ID. Sans elle, le téléversement est accepté puis rejeté par
   Apple avec un courriel « no suitable application records were found ».

### 10.2 Créer le certificat et le `.p12` — sans Mac

Tout le parcours Apple se fait **sans posséder de Mac** : la demande de
signature (CSR) et l'assemblage du `.p12` sont des gestes openssl, sur
n'importe quelle machine Linux ou Windows (Git Bash). C'est le chemin
recommandé ici, puisque le job iOS existe précisément pour bâtir sans Mac.

```bash
# 1. La clé privée et la demande de signature (CSR) — la clé reste chez vous,
#    elle est LA moitié secrète du futur certificat : à sauvegarder comme un
#    keystore (§5), la perdre = tout refaire.
openssl req -new -newkey rsa:2048 -nodes \
  -keyout carlys-distribution.key \
  -out carlys-distribution.csr \
  -subj "/emailAddress=vous@exemple.fr/CN=Carlys Distribution/C=FR"

# 2. Sur developer.apple.com → Certificates → « + » → Apple Distribution :
#    téléverser carlys-distribution.csr, télécharger distribution.cer.

# 3. Assembler le .p12 (certificat + clé). Le mot de passe demandé à l'export
#    devient le secret IOS_DISTRIBUTION_P12_PASSWORD.
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export \
  -inkey carlys-distribution.key -in distribution.pem \
  -out carlys-distribution.p12

# 4. Encoder pour les secrets GitHub (syntaxe GNU ; sur macOS : base64 -i X | tr -d '\n')
base64 -w0 carlys-distribution.p12
base64 -w0 "Carlys App Store.mobileprovision"
```

**Avec un Mac**, l'équivalent passe par Trousseaux d'accès : Assistant de
certification → Demander un certificat (CSR), puis, une fois le `.cer` ouvert,
catégorie **Mes certificats**, clic droit sur la ligne « Apple Distribution: … »
qui se **déplie** sur une clé privée (pas la clé seule, pas le certificat seul)
→ Exporter → `.p12`. Un `.p12` exporté depuis le certificat seul ne contient
pas la clé : le job le détecte (« Aucun certificat de DISTRIBUTION valide »)
et le dit.

### 10.3 Les trois secrets de signature

Ils vont **ensemble** ; sans l'un d'eux, le job **échoue** — à rebours du bundle
Android, où l'APK est déjà livré et se suffit. Ici, il n'existe pas d'`.ipa`
« signé en debug » qui s'installerait quand même : sans certificat ni profil,
rien ne s'installe nulle part, et un job qu'on a demandé et qui ne livre rien
doit le dire en rouge.

| Secret | Rôle | Comment l'obtenir |
| --- | --- | --- |
| `IOS_DISTRIBUTION_P12_BASE64` | certificat Apple Distribution **et** sa clé privée | §10.2, première commande |
| `IOS_DISTRIBUTION_P12_PASSWORD` | mot de passe donné à l'export | celui saisi dans Trousseaux d'accès |
| `IOS_PROVISIONING_PROFILE_BASE64` | profil App Store Connect du bundle | §10.2, seconde commande |

Pas d'identifiant d'équipe à saisir : le profil le porte, le job l'y lit.

Comme les secrets Android, ils **ne sont pas une sauvegarde** : gardez le `.p12`
et son mot de passe dans un gestionnaire de mots de passe. La perte est moins
grave qu'un keystore Android — Apple laisse révoquer un certificat et en créer un
autre — mais elle coûte une régénération complète : certificat, profil, secrets.

### 10.4 TestFlight : la clé API App Store Connect

Trois secrets de plus, facultatifs mais **ensemble**. Sans eux, l'`.ipa` est un
artefact à déposer avec l'application **Transporter** — qui est une application
macOS : **sans Mac, la clé API est donc le seul chemin vers TestFlight**, et
ces trois secrets sont obligatoires en pratique. Le dépôt lui-même n'a lieu que
sur une exécution avec la case **publier** (§4.6) — jamais sur une poussée.

> App Store Connect → Users and Access → **Integrations** → App Store Connect
> API → Team Keys → « + » → nom libre, rôle **App Manager** → Generate.

| Secret | Valeur |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | l'identifiant de la clé — dix lettres et chiffres, c'est le `<KEY_ID>` du nom de fichier `AuthKey_<KEY_ID>.p8` |
| `APP_STORE_CONNECT_ISSUER_ID` | l'Issuer ID affiché en haut de la page (un UUID, commun à toutes les clés de l'équipe) |
| `APP_STORE_CONNECT_API_KEY_BASE64` | le fichier `.p8`, encodé : `base64 -i AuthKey_<KEY_ID>.p8 \| tr -d '\n'` |

**Le `.p8` ne se télécharge qu'une fois.** Apple ne le redonne jamais ; perdu, on
révoque la clé et on en crée une autre. Rangez-le avec le `.p12`.

### 10.5 Activer le job — et ce que ça coûte

Le job iOS ne tourne **jamais** de lui-même. Trois façons de le demander :

- **à chaque poussée**, comme l'APK : variable de dépôt `CARLYS_IOS_BUILDS`
  valant `oui` (Settings → Secrets and variables → Actions → **Variables**) —
  il construit alors, mais ne dépose jamais rien sur TestFlight ;
- **une fois, pour construire** : Actions → `mobile-recette` → Run workflow →
  cocher **ios** ;
- **pour publier sur TestFlight** : les cases **ios** ET **publier** ensemble
  (§4.6) — publier seule dépose le bundle Android mais ne lance pas ce job.

Le prix, c'est la raison de ce choix : sur un dépôt privé, GitHub facture une
minute de runner macOS **dix fois** une minute Linux, et une archive Xcode d'une
application Flutter avec Firebase prend vingt à trente minutes à froid. À chaque
poussée sous `apps/mobile/`, cela se compte. Le cache CocoaPods du job réduit
les exécutions suivantes ; il ne les rend pas gratuites. Une pratique raisonnable :
laisser la variable absente, cocher la case quand un build iOS est utile, et ne
la poser à `oui` que le temps d'une campagne de test.

### 10.6 Ce que le job vérifie avant de compiler

Chaque contrôle porte le message que `xcodebuild` ne donnerait pas, et se joue en
quelques secondes plutôt qu'après vingt minutes d'archive :

- les **trois secrets** présents, avec l'App ID à enregistrer dans le message
  d'échec ;
- le `.p12` **déballé et importé** dans un trousseau créé pour le job, détruit
  à la fin quoi qu'il arrive — même règle que le keystore Android ;
- une identité **Apple Distribution** (ou « iPhone Distribution », l'ancien
  nom) **valide** : non expirée, chaîne complète jusqu'à Apple. Si le `.p12` a
  été exporté sans l'intermédiaire WWDR, le job importe ceux qu'Apple publie
  et revérifie ;
- le profil : de type **App Store** (ni Ad Hoc, ni Development, ni
  Enterprise), pour **ce** bundle, **non expiré**, et **embarquant l'un des
  certificats** importés — la paire dépareillée est l'erreur la plus
  fréquente de toute la signature iOS. C'est ce certificat-là qui signe,
  désigné par son empreinte SHA-1 : un `.p12` qui contient l'ancien et le
  nouveau certificat ne crée aucune ambiguïté ;
- puis seulement : signature manuelle branchée par `ios/Flutter/Release.xcconfig`
  (l'équivalent du second bloc `android { }` — rien n'est édité dans
  `project.pbxproj`), `ExportOptions.plist` écrit, archive, export,
  téléversement.

Le job déclare `ITSAppUsesNonExemptEncryption = false` dans `Info.plist` :
l'application ne chiffre rien elle-même, elle parle HTTPS, ce qui est exempt.
Sans cette déclaration, chaque build attendrait dans App Store Connect qu'un
humain réponde « Missing Compliance ».

### 10.7 Après le téléversement, et les limites

- **Apple traite le build** dix à trente minutes après le téléversement, puis
  il apparaît dans App Store Connect → TestFlight. Les testeurs **internes**
  (membres de l'équipe) le reçoivent dès qu'un groupe interne le contient ;
  les testeurs **externes** exigent un examen (Beta App Review, un à deux
  jours pour le premier build).
- **Le numéro de build** (`CFBundleVersion`) est le numéro d'exécution du
  workflow, comme le `versionCode` Android : TestFlight refuse deux fois le
  même, et celui-ci ne recule jamais.
- **Lancez le build une fois** depuis TestFlight avant de l'ouvrir aux testeurs
  — §3.3 vaut pour iOS mot pour mot.
- **La production n'a pas de job iOS.** `mobile-production` ne construit
  qu'Android ; ajouter iOS signifierait recopier le job de recette avec
  `CARLYS_FLAVOR=production`, des secrets d'**environnement** derrière
  l'approbation, et accepter le coût macOS à chaque promotion. Le jour où une
  publication App Store se prépare, c'est ce job de recette qui sert de
  modèle, pas une page blanche.
- **Les notifications push iOS** ne sont pas couvertes : elles demandent une
  clé APNs chez Apple, la capacité Push sur l'App ID (donc un profil
  régénéré), un fichier `Runner.entitlements` portant `aps-environment` que
  le gabarit Flutter n'a pas, et un `GoogleService-Info.plist` distinct du
  fichier Android. Sans elles, le push est simplement inactif sur iOS, le
  reste de l'application vit normalement.

---

## À lire à côté

- [`docs/deployment/mise-en-route-serveur.md`](./mise-en-route-serveur.md) —
  le guide de bout en bout. **§8 « Les builds mobiles »** donne les commandes
  `flutter build` à lancer **sur votre poste** (le pendant local de ce document,
  utile quand on veut compiler sans passer par la CI) et la configuration
  Firebase ; **§9 « Passer en production »** couvre les textes légaux et la
  bascule du serveur, qui conditionnent toute soumission.
- [`docs/development/poste-de-travail.md`](../development/poste-de-travail.md) —
  installer le SDK Flutter épinglé, l'Android SDK et ses licences.
- `.github/workflows/mobile-recette.yml` et
  `.github/workflows/mobile-production.yml` — les workflows eux-mêmes ; leurs
  commentaires portent le détail de chaque garde.
- `scripts/server/promote.sh` — le geste humain côté serveur, dont l'approbation
  d'environnement est le pendant mobile.

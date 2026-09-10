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
| Entrée `sha` | facultative (vide = tête de la branche) | **obligatoire** |
| `CARLYS_FLAVOR` | `staging` | `production` |
| Adresses visées | `api-staging.DOMAINE`, `app-staging.DOMAINE` | `api.DOMAINE`, `app.DOMAINE` |
| Approbation humaine | non | **oui** — environnement GitHub à « required reviewers » |
| Textes légaux complets exigés | non | **oui** — refus tant qu'un `[À COMPLÉTER : …]` subsiste |
| Le commit doit déjà exister en recette | — | **oui** (règle « build once ») |
| `.apk` produit | toujours, sans aucun secret | oui, mais **de vérification seulement** |
| `.aab` produit | seulement si la signature est configurée | **toujours** — sinon le workflow échoue |
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
| **Play Store, Galaxy Store** | `.aab` | **keystore obligatoire** | 4 secrets (§4) | oui, une fois le keystore créé |
| **App Store (iOS)** | `.ipa` | certificat + profil Apple | compte Apple Developer | **non — un macOS est indispensable** |

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

**iOS n'est pas oublié, il est écarté sciemment.** Apple exige Xcode, donc
macOS ; ni le serveur ni les runners Linux ne peuvent produire un `.ipa`. Ce
qu'il faudrait pour l'ajouter — un runner `macos-latest`, un certificat Apple
Distribution, un profil de provisionnement, une clé API App Store Connect, et
l'équivalent iOS de la signature Gradle — est listé en tête de
`.github/workflows/mobile-production.yml`. Le vrai arbitrage y est aussi : une
minute de runner macOS est facturée **dix fois** une minute de runner Linux.

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
   les deux scripts qui portent l'identité Android de l'application).
2. **Ouvrir l'onglet Actions**, l'exécution la plus récente. Compter une
   vingtaine de minutes à froid, moins ensuite grâce aux caches Dart et Gradle.
3. **Télécharger l'artefact** en bas de la page d'exécution. Son nom porte les
   douze premiers caractères du sha construit — ce n'est pas décoratif : c'est ce
   sha qu'il faudra renseigner plus tard pour la production. Le récapitulatif de
   l'exécution (onglet Summary) fait foi sur le contenu exact de l'artefact.
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
   reprendre la numérotation d'un dépôt Play existant : par défaut, le numéro
   d'exécution du workflow est utilisé, et il ne recule jamais.
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
- **iOS en entier** : `.ipa`, certificats, profils, TestFlight. Un macOS avec
  Xcode est indispensable (§2).
- **Le versionCode.** Play refuse un versionCode déjà téléversé. Le workflow
  utilise par défaut le numéro d'exécution, qui ne recule jamais ; si vous
  reprenez un dépôt existant dont la numérotation est plus haute, renseignez
  `build_number` au premier passage.
- **Les notifications push.** Les quatre valeurs Firebase ne sont pas injectées
  par les workflows. Leur absence désactive proprement le push, le reste de
  l'application vivant normalement — les ajouter est un geste délibéré, décrit au
  §8 du guide serveur. Attention : `google-services.json` décrit l'application
  **Android**, l'équivalent iOS est `GoogleService-Info.plist` et son `appId`
  diffère. Prévoyez deux fichiers.

---

## 9. Quand ça ne marche pas

Les messages d'erreur des workflows sont écrits pour être suffisants à eux seuls.
Voici les quatre qu'on rencontre en pratique.

| Ce que dit l'exécution | Ce qui se passe | Quoi faire |
| --- | --- | --- |
| « Variable de dépôt `CARLYS_DOMAIN` absente » ou « mal formée » | la variable manque, ou porte un schéma / une barre / un port | §3.1 — le domaine **nu**, rien d'autre |
| « Bundle de magasin NON produit » (avertissement, recette) | les quatre secrets de signature ne sont pas visibles par ce workflow | c'est le **cas nominal** si vous les avez posés sur l'environnement (§4.5). L'`.apk` est livré normalement |
| « Ce commit n'a pas été construit en recette » | la règle « build once » : aucun artefact de recette ne porte ce sha | relancer la recette **sur ce sha** (champ « sha » du Run workflow), l'installer, l'essayer, revenir |
| « L'artefact de recette a expiré » | GitHub supprime les artefacts après la rétention du dépôt (90 jours par défaut) | relancer la recette sur ce sha — et en profiter pour ré-essayer un commit vieux de plusieurs mois — ou promouvoir un commit plus récent |
| « Les textes légaux ne sont pas prêts » | un `[À COMPLÉTER : …]` subsiste dans `docs/legal/` | les compléter, pousser, reconstruire en recette, relancer sur le nouveau sha. Aucun contournement |
| « L'approbation humaine n'est pas armée » | l'environnement `mobile-production` n'existe pas, ou n'a pas de reviewer | §6 |
| « Secrets de signature absents » (après approbation) | les quatre secrets ne sont pas sur l'environnement | §4.4 et §4.5 |

Deux limites à connaître, dites franchement plutôt que découvertes :

- La garde « build once » prouve que le commit a été **fabriqué** en recette, pas
  qu'un humain l'a **installé et essayé**. Exactement comme, côté serveur,
  vérifier qu'une image existe ne prouve pas qu'on l'a fait tourner. C'est
  l'approbation humaine qui couvre ce trou — d'où l'insistance du §7, point 3.
- Elle peut refuser un commit ancien dont l'artefact a **expiré**, alors qu'il
  avait bel et bien été construit. C'est un faux refus, jamais un faux accord :
  elle se trompe du bon côté.

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

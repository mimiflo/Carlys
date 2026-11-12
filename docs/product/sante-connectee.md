# Santé connectée — les pas et la balance (Health Connect, Apple Santé)

Tranche D des ajouts de novembre 2026 (`ajouts-novembre-2026.md`). Carlys
**lit** trois données dans le service de santé du téléphone — les pas, le
poids, le taux de masse grasse — et n'y écrit rien.

| Donnée | Où elle s'affiche | Où elle va |
| ------ | ----------------- | ---------- |
| Pas du jour | accueil, rangée « PAS » sous la grille du jour | **nulle part** : lue, affichée, oubliée |
| Poids, masse grasse | Progrès (dernière mesure, historique, frise) | serveur, comme une pesée saisie (`POST /body-metrics`) |

## La dépendance : `health`

Le paquet Flutter [`health`](https://pub.dev/packages/health) (CARP, Université
technique du Danemark, licence MIT) couvre **les deux** plateformes : Health
Connect sur Android, HealthKit sur iOS.

- **Pourquoi lui.** C'est le seul greffon maintenu qui couvre les deux. Les
  alternatives n'en couvrent qu'une : `flutter_health_connect` (Android seul,
  peu suivi), les greffons HealthKit seuls (`health_kit_reporter`…). En prendre
  deux, c'était deux API, deux jeux de bogues et deux mises à jour à suivre
  pour trois lectures. Écrire le pont natif soi-même (Kotlin + Swift) coûtait
  plus que le greffon, sans le banc d'essai de ses utilisateurs.
- **Ce qu'il tire.** `device_info_plus`, `carp_serializable`,
  `json_annotation`, `intl` (déjà là) ; côté Android
  `androidx.health.connect:connect-client`. Rien qui parle au réseau.
- **La version : 13.3.1, pas 13.3.2.** La 13.3.2 (août 2026) tire
  `device_info_plus` 13 puis `win32` 6, incompatible avec
  `flutter_secure_storage` 9 (`win32` 5). La 13.3.1 date de février 2026 :
  bien plus de deux semaines.
- **Isolé derrière un port.** `HealthDataSource`
  (`lib/features/health/domain/health_data_source.dart`) ; l'adaptateur
  `HealthPluginDataSource` est le seul fichier qui importe le greffon. Les
  tests passent par `FakeHealthDataSource` (`test/support/`) : aucun ne
  touche le greffon.

## Les couches

```
réglages / accueil / Progrès  (widgets : aucun appel au greffon)
        │
HealthConnectionController (connexion, objectif)   todayStepsProvider   HealthWeighingImport
        │                                                │                      │
        │                                         ReadTodaySteps      ImportHealthWeighings
        └────────────────────────────── HealthDataSource ─────────────┤
                                                                       └── ProgressRepository.addBodyMetric
```

- `domain/health_data_source.dart` — le port (`availability`,
  `requestReadAccess`, `hasReadAccess`, `stepsBetween`, `weighingsBetween`),
  la pesée `HealthWeighing`, et `HealthImportLedger` (le curseur d'import).
- `domain/usecases/` — `ReadTodaySteps` (minuit local → maintenant) et
  `ImportHealthWeighings` (fenêtre, bornes, identifiant dérivé, envoi).
- `data/` — l'adaptateur du greffon et `HealthPrefsStore`
  (`SharedPreferences`, par compte : connexion, objectif, dernier import).
- `presentation/` — le contrôleur, les providers, le groupe de réglages,
  et l'enrobage d'import de Progrès. La justification des permissions est
  native (`HealthPrivacyActivity`, plus bas).

## La connexion, dans les réglages

Groupe « SANTÉ CONNECTÉE » des réglages du profil, sous « Entraînement » (qui
mène aux mesures corporelles) : une ligne « Santé connectée », la passerelle
du téléphone en valeur (« Health Connect » ou « Apple Santé ») et un
interrupteur.

| Issue de l'activation | Ce que l'écran fait |
| --------------------- | ------------------- |
| Les trois lectures accordées | connecté ; la ligne « Objectif de pas » apparaît |
| Refus (ou une lecture sur trois manquante) | popup « Accès refusé » : ce que Carlys lit, la marche à suivre (Health Connect › Autorisations des applications › Carlys ; sur iPhone, Réglages › Santé › Accès aux données et appareils), « Réessayer » ; puis une ligne qui y ramène |
| Android 9 à 13 sans Health Connect | popup « Health Connect à installer », bouton vers le Play Store ; puis une ligne « Installer » |
| Téléphone que Health Connect ne prend pas en charge (Android 8, certains profils et appareils) | ligne « Health Connect ne fonctionne pas sur ce téléphone » : exact, sans deviner la cause, que Health Connect ne donne pas |
| Autorisation retirée APRÈS coup dans Health Connect | à la relecture, la connexion passe en refusée (même ligne) au lieu d'afficher zéro pas |

- **Mémorisée sur l'appareil, par compte** (`health.connected.<id>`) :
  l'autorisation Health Connect vaut pour le téléphone, mais sur un téléphone
  partagé le compte suivant n'importe pas les pesées du précédent tant qu'il
  n'a pas activé la connexion lui-même.
- **Les trois lectures, ou aucune.** Android rend « accordé » dès qu'une
  seule l'est ; on revérifie les trois. Une connexion à moitié aurait des
  comportements à moitié expliqués.
- **iOS ne dit jamais un refus de lecture** (choix d'Apple). La demande
  montrée vaut connexion ; un refus s'y lit comme « 0 pas » et aucune
  pesée. La marche à suivre de la popup vaut aussi pour ce cas.
- **Désactiver** arrête toute lecture ; l'autorisation se retire dans Health
  Connect ou Réglages › Santé. Carlys ne la révoque pas lui-même : iOS ne le
  permet pas, et Android ne l'applique qu'au redémarrage de l'application.

## Les pas, sur l'accueil

- **Une rangée pleine largeur sous la grille 2 × 2** (`TodayGrid.steps`),
  même cellule (`TodayCell`), même lecture « fait / visé / reste » :
  « 6 214 / 8 000 pas · reste 1 786 pas ». Une cinquième cellule aurait
  cassé le 2 × 2 ; la rangée s'y ajoute sans rien déplacer. Sans geste : les
  pas se comptent en marchant.
- **Non connecté : pas de cellule.** L'accueil est l'écran le plus vu ; une
  invitation à connecter y ferait chaque jour la réclame d'une option qu'on a
  peut-être déjà écartée. L'entrée est dans les réglages, et la grille reste
  exactement celle d'avant.
- **Lecture** à l'ouverture, au retour au premier plan, toutes les cinq
  minutes tant que l'accueil est affiché (`stepsRefreshInterval`), et au
  passage de minuit (`currentDayProvider`). Le total vient de la plateforme,
  qui dédoublonne téléphone et montre.
- **Lecture impossible** : « — · lecture impossible », jamais un zéro inventé.
- **Les pas restent sur l'appareil**, comme l'eau (`nutrition.md`,
  « Hydratation ») : aucune API, aucune écriture, pas même en base locale. Un
  compteur du jour n'a rien à raconter à un autre appareil.

### L'objectif de pas : 8 000 par défaut, réglable

Pas d'objectif inventé : la cible s'affiche parce que la cellule du jour se lit
« fait sur visé », et elle se **règle** (ligne « Objectif de pas », de 1 000 à
50 000, gardée sur l'appareil). **8 000 par défaut, pas 10 000** : 10 000 vient
d'un podomètre japonais de 1965 ; la méta-analyse de Paluch et al. (*The
Lancet Public Health*, 2022, 15 cohortes) situe le plateau du bénéfice sur la
mortalité vers 6 000 à 8 000 pas par jour après 60 ans, 8 000 à 10 000 avant.
8 000 est le seuil où le bénéfice commence à plafonner pour la plupart des
adultes. Constante : `HealthSettings.defaultStepsGoal`.

## Les pesées, dans Progrès

`ImportHealthWeighings`, déclenché par `HealthImportTrigger` autour de l'écran
Progrès : à son **ouverture**, au **retour au premier plan**, et dès que la
connexion **s'active**. Au plus une fois par quart d'heure, et **un seul à la
fois** : ouverture et retour au premier plan qui se croisent attendent le même
import. La courbe ne se relit que si un poids qu'elle n'a pas est arrivé.

- **Par le chemin d'une saisie** : `ProgressRepository.addBodyMetric`
  (`POST /body-metrics`), qui accepte désormais un `id` fourni. Mêmes bornes
  serveur, même correction, même suppression, même cascade à la suppression
  du compte. Aucune route, aucune migration.
- **Bornes d'import**, plus serrées que celles de l'API (faites pour ne
  jamais refuser une saisie vraie) : poids 20 à 350 kg, masse grasse 2 à
  75 %, arrondis à deux décimales. Une balance frôlée (0,4 kg), une masse
  grasse lue en fraction (0,25) n'entrent pas. Une pesée datée dans le futur
  (horloge de la balance) non plus. Un refus du serveur (400) écarte la pesée
  sans bloquer les suivantes ; une panne réseau, elle, arrête l'import et le
  curseur ne bouge pas.
- **Depuis le dernier import**, avec **sept jours** de recouvrement : une
  pesée de 7 h synchronisée à 9 h par l'application de la balance arrive
  datée de 7 h, et une balance restée hors réseau un week-end livre ses
  pesées le lundi. Relire ne coûte rien : même identifiant, aucune ligne. Le premier import remonte 30 jours (Health Connect ne sert de toute
  façon que les 30 jours qui précèdent l'autorisation). Le curseur est par
  compte, sur l'appareil.
- **Rien de Carlys** : une mesure dont la source est une application
  `com.carlys.*` est ignorée. Carlys n'écrit rien aujourd'hui ; la règle tient
  pour le jour où il écrirait.
- **Apple Santé rend la masse grasse en fraction** (0,25 pour 25 %) :
  l'adaptateur la ramène en pourcentage. Health Connect la rend déjà en
  pourcentage.

### Jamais deux fois : l'identifiant dérivé

L'identifiant de la mesure est un **UUID v5** (espace de noms fixe
`healthWeighingNamespace`) de `compte | type | seconde de la pesée`
(`weighingMetricId`). La même pesée relue — depuis ce téléphone réinstallé, ou
depuis un autre — retombe sur la même ligne, et le serveur, idempotent par
identifiant, ne crée rien.

**Pourquoi pas l'identifiant de l'enregistrement source**, comme on l'avait
d'abord envisagé : Health Connect numérote ses enregistrements **par
téléphone**. La même pesée, écrite par l'application de la balance sur deux
téléphones, y porte deux identifiants, et serait importée deux fois. La seconde
de mesure, elle, est la même partout ; deux pesées distinctes d'une même
personne à la même seconde n'existent pas.

### Un identifiant recalculable, rangé par le SERVEUR dans l'espace du compte

Cet identifiant n'est pas un secret : qui connaît le compte et l'heure le
recalcule. Gardé tel quel, il laissait un compte A déposer AVANT B la pesée
de B (la vraie, ensuite, retombait en silence sur la ligne de A, refusée par
un 409) et sonder les heures de pesée de B (un 409 disait « elle existe »).
La frontière de confiance est le serveur : `storedBodyMetricId`
(`apps/api/src/modules/progress/application/body-metric-id.ts`) range tout
identifiant **v5** reçu dans l'espace du compte, `uuidv5(userId, id)`.

- Deux comptes qui envoient le même identifiant obtiennent deux lignes, deux
  201 : rien à réserver, rien à sonder.
- Le rejeu d'un même compte retombe sur SA ligne : idempotence intacte.
- Le résultat reste un v5 : l'application le lit toujours « importée ».
- La réponse porte l'identifiant **stocké**, que la liste, la correction
  (`PATCH`), la suppression (`DELETE`), la frise et le coach utilisent
  ensuite : aucun de ces chemins ne revoit l'identifiant envoyé.
- Un v4 (saisie à la main) est gardé tel quel : tiré au hasard, il ne se
  devine pas, et son 409 entre comptes reste le garde-fou d'avant.

Tenu par l'e2e « une pesée importée (UUID v5) : A ne peut ni réserver ni
sonder celle de B ». Côté appli, un 409 resté possible (serveur d'avant)
écarte la pesée sans bloquer les suivantes (`import_health_weighings_test`).

### Une pesée supprimée ne revient pas — sans liste locale

La suppression est **logique** côté serveur : la ligne reste, marquée
supprimée, et recréer son identifiant ne la ressuscite pas (test e2e
« supprime une mesure », `apps/api/test/progress.e2e-spec.ts`). Comme
l'identifiant d'une pesée ne change jamais, la relire au prochain import —
sur n'importe quel appareil, même réinstallé — retombe sur la ligne
supprimée et ne fait rien. Une liste locale d'identifiants supprimés aurait
fait la même chose en moins bien : perdue à la réinstallation, inconnue de
l'autre téléphone.

### « Importée », sans champ en base

Une mesure saisie naît sous un **UUID v4**, une pesée importée sous un
**UUID v5** : la version, inscrite dans l'identifiant (son 15e caractère), suffit
à les distinguer (`BodyMetricEntry.imported`), sur tous les appareils, sans
migration. La dernière mesure écrit « · importée de la balance », la ligne de
l'historique « · IMPORTÉE » (et son libellé d'accessibilité le dit). Un champ
`source` en base n'apporterait que le nom de la passerelle, qui ne sert à
rien à l'écran. Le jour où il servira, une migration l'ajoutera.

## Configuration native — par `scripts/android_branding.sh`

`android/` et `ios/` ne sont pas versionnés : ils sont engendrés par
`scripts/bootstrap_mobile.sh`, qui appelle `android_branding.sh` — le même
script que la CI de recette et de production. Le bloc « Santé connectée » y
pose :

**Android**

- `READ_STEPS`, `READ_WEIGHT`, `READ_BODY_FAT` (`android.permission.health.*`),
  et **aucune** permission d'écriture ;
- dans `<queries>` : le paquet `com.google.android.apps.healthdata` (Health
  Connect est une application à part sur Android 9 à 13) et l'intention
  `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` ;
- la **justification des permissions**, exigée par Google Play : une petite
  activité NATIVE, `HealthPrivacyActivity` (`Theme.NoDisplay`), qui ouvre la
  politique de confidentialité dans le navigateur puis se ferme, comme
  l'exemple officiel de Health Connect. Elle porte le filtre
  `ACTION_SHOW_PERMISSIONS_RATIONALE` (Android 13 et moins), et l'alias
  `ViewPermissionUsageActivity` (`VIEW_PERMISSION_USAGE`, catégorie
  `HEALTH_PERMISSIONS`, protégé par `START_VIEW_PERMISSION_USAGE`) la vise
  pour Android 14 et plus. L'adresse est celle de l'application
  (`CARLYS_PUBLIC_WEB_BASE_URL` + `/privacy`), lue par Gradle dans les
  `--dart-define` et posée en `manifestPlaceholders` ; défaut de
  développement `http://localhost:3001`, comme `AppEnvironment`. La première
  version passait par l'activité Flutter et une route `/sante-connectee` :
  un second moteur Flutter possible, une exception au routeur. Retirées ;
- `MainActivity` **réécrite**, en `FlutterFragmentActivity` et rien
  d'autre : le greffon `health` demande les permissions par
  `registerForActivityResult`, qu'il obtient en convertissant l'activité
  en `ComponentActivity` ; une `FlutterActivity` ferait échouer cette
  conversion ;
- `minSdk = maxOf(flutter.minSdkVersion, 26)` : `connect-client` exige
  l'API 26, le gabarit de Flutter 3.44 descend à 24. **Changement visible** :
  Android 7 (API 24, 25) ne reçoit plus de mise à jour.
- **Dépendance alpha** : le greffon tire `androidx.health.connect:connect-client`
  en `1.2.0-alpha02` (sa propre version, non choisie ici). À surveiller à
  chaque montée du greffon ; consigné dans `builds-mobiles.md`.

**iOS**

- `NSHealthShareUsageDescription`, en français ; **pas**
  `NSHealthUpdateUsageDescription` (sans lui, iOS refuse toute demande
  d'écriture) ;
- la capacité HealthKit, SANS condition : `ios/Runner/Runner.entitlements`
  (`com.apple.developer.healthkit`, `healthkit.access` vide) et
  `CODE_SIGN_ENTITLEMENTS` sur les trois configurations de la cible Runner.
  La recette iOS (`mobile-recette.yml`, étape « Profil de provisionnement »)
  refuse AVANT l'archive un profil sans `com.apple.developer.healthkit`
  (« régénère le profil après avoir coché HealthKit ») et un App ID
  générique, qui ne peut porter aucune capacité.

Le script reste **idempotent** : relancé, il ne change plus un octet.
`scripts/ci/tests/android_branding_test.sh` le prouve sur un arbre factice à
la forme du gabarit, sans Flutter, et vérifie chaque élément ci-dessus (dont
l'absence de toute permission d'écriture). Il tourne dans
`./scripts/check_infra.sh` et donc dans `infra-ci`, avec `shellcheck` sur
`android_branding.sh`, `mobile_platforms.sh` et `bootstrap_mobile.sh`.
`check_mobile.sh` n'engendre pas `android/` (la CI mobile non plus) : il
couvre le code Dart, pas la configuration native.

## Ce qui reste à faire hors du dépôt

**Rien de cette tranche ne s'EXÉCUTE dans le conteneur de développement** :
pas de téléphone, pas de Xcode. Les tests passent par la source factice.
Côté Android, l'APK de debug a été COMPILÉ dans le conteneur (SDK en ligne
de commande, `bootstrap_mobile.sh` puis `flutter build apk --debug`) :
manifeste fusionné, Kotlin des deux activités et Gradle passent (le
12 novembre 2026). Cette compilation a d'ailleurs attrapé un vrai défaut :
`java.util.Base64` écrit dans le corps du `build.gradle.kts` ne compile pas
(`java` y désigne l'extension Gradle) ; d'où l'import en tête. Le manifeste de
l'APK relu par `aapt2` : `minSdkVersion` 26, les trois `READ_*` et aucune
écriture, `HealthPrivacyActivity` avec son adresse résolue
(`--dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://carlys.example` →
`https://carlys.example/privacy`), l'alias qui la vise. iOS n'a été que relu.

### Google Play Console

1. **Déclaration Health Connect** (Contenu de l'application › Health
   Connect) : déclarer les trois types lus (Pas, Poids, Masse grasse), en
   lecture seule, l'usage de chacun, et l'URL de la politique de
   confidentialité. Les usages, TOUS :
   - pas : affichage du jour face à l'objectif, sur l'appareil, jamais
     envoyés ;
   - poids et masse grasse : envoyés au serveur comme une saisie, pour la
     courbe et la frise de Progrès, le rapport métabolique (métabolisme de
     base, dépense, cible calorique, macros, eau, IMC, sur la dernière
     pesée) et les réponses du coach, qui tourne sur le serveur de Carlys ;
   - jamais de publicité, jamais revendus, jamais partagés.
 Google relit la déclaration
   avant la mise en production ; sans elle, la piste de production refuse
   l'application.
2. **Sécurité des données** : ajouter « Santé et remise en forme » (pas,
   poids, masse grasse), collectées pour les fonctionnalités de
   l'application, non partagées, chiffrées en transit, supprimables.
3. Vérifier, sur la piste interne, que le lien « Règles de confidentialité »
   de la page d'autorisations de Health Connect ouvre bien la politique
   dans le navigateur (`HealthPrivacyActivity`), application fermée puis
   ouverte.

### App Store

1. **App ID** : cocher **HealthKit** (developer.apple.com › Identifiers), puis
   **régénérer le profil de provisionnement** et remplacer le secret
   `IOS_PROVISIONING_PROFILE_BASE64` (`docs/deployment/builds-mobiles.md`,
   § 10.1) — sans quoi la signature du job iOS échoue.
2. **App Privacy** (App Store Connect) : « Santé et forme physique » et
   « Données de remise en forme », liées à l'identité, non utilisées pour le
   suivi publicitaire.
3. **Revue** : dans les notes au réviseur, dire que l'application lit pas,
   poids et masse grasse, en lecture seule, comment l'activer (Profil ›
   Réglages › Santé connectée), et que l'interface montre clairement la
   fonction (rangée « PAS » de l'accueil, mention « importée »). Apple refuse
   une application qui demande HealthKit sans fonction visible (guideline
   2.5.1) ou stocke ces données dans iCloud (Carlys ne le fait pas).
4. Si App Store Connect signale un motif manquant
   `NSHealthUpdateUsageDescription` (ITMS-90683) alors que Carlys n'écrit
   rien, ajouter la clé avec un texte qui le dit — sans demander d'écriture.

### Sur un vrai téléphone

- Android 14+ (Health Connect intégré), puis Android 13 sans l'application
  Health Connect (popup d'installation) ; refus, puis autorisation depuis
  Health Connect ; retrait de l'autorisation après coup.
- Une balance réelle (Withings, Xiaomi, Renpho…) qui écrit dans Health
  Connect / Apple Santé : la pesée apparaît dans Progrès, une seule fois ;
  supprimée, elle ne revient pas ; même compte sur un second téléphone, pas
  de doublon.
- iPhone : la masse grasse arrive en pourcentage (25 et non 0,25) ; avec une
  Apple Watch, les pas ne sont pas comptés deux fois.
- Le lien de justification depuis Health Connect, application fermée puis
  ouverte.

## Cas limites, et ce que Carlys en fait

- **Pesée corrigée ou réattribuée dans l'application de la balance** (le
  poids d'un enfant rangé ensuite sur son propre profil, par exemple) : elle
  garde son heure, donc son identifiant, et le serveur rend la ligne déjà là
  sans la toucher. **Elle n'est pas reprise** : la personne la corrige ou
  supprime la pesée dans Carlys. Pas de correction automatique : elle
  écraserait aussi une correction faite à la main dans Carlys.
- **iOS ne dit jamais un refus de lecture** : un refus s'y voit comme zéro
  pas et aucune pesée ; la popup donne la marche à suivre dans Réglages.
- **Health Connect désinstallé après la connexion** : la relecture des
  autorisations répond « non », la connexion passe en refusée.
- **Une seule lecture sur trois accordée** : vu comme un refus (les trois
  ou aucune).
- **Pesée supprimée relue dans la fenêtre de recouvrement** : le serveur ne
  la ressuscite pas, mais la renvoie ; la courbe se relit alors une fois de
  trop (au plus une par quart d'heure).
- **Déconnexion ou suppression du compte** : la purge locale efface toute
  clé `health.` (connexion, objectif, curseur d'import, qui dit quand la
  personne s'est pesée pour la dernière fois).

## Tests

| Fichier | Ce qu'il tient |
| ------- | -------------- |
| `test/features/health/import_health_weighings_test.dart` | UUID v5 stable et reconnaissable, insensible à l'enregistrement source ; bornes et arrondi ; fenêtre de 30 jours puis depuis le dernier import (recouvrement, un quart d'heure) ; idempotence après réinstallation ; pesée supprimée non réimportée ; hors ligne (curseur immobile) ; refus serveur écarté ; un curseur par compte |
| `test/features/health/health_settings_section_test.dart` | non connecté, accordé, refusé (popup, marche à suivre, réessai), Health Connect à installer, téléphone non pris en charge, autorisation retirée, objectif borné, désactivation |
| `test/features/health/today_steps_test.dart` | pas de cellule sans connexion ; « fait / visé / reste » ; objectif réglé ; relecture au premier plan et toutes les cinq minutes ; lecture impossible |
| `test/features/health/weighing_import_screen_test.dart` | import à l'ouverture de Progrès, rien sans connexion, mention « importée » (ligne et accessibilité) |
| `test/features/health/health_weighing_import_test.dart` | un seul import à la fois ; la courbe ne se relit que pour un poids nouveau |
| `test/core/local_account_purge_test.dart` | toute clé `health.` part avec le compte |
| `apps/api/test/progress.e2e-spec.ts` | un UUID v5 est rangé dans l'espace du compte ; A ne peut ni réserver ni sonder la pesée de B ; recréer une mesure supprimée ne la ressuscite pas |
| `apps/api/src/modules/progress/application/body-metric-id.spec.ts` | UUID v5 conforme à la RFC ; v5 par compte, v4 intact |
| `scripts/ci/tests/android_branding_test.sh` | la configuration native, en lecture seule, idempotente ; justification par l'activité native ; la recette iOS vérifie HealthKit |

# Le Mentor Carlys

Le personnage-guide de l'application. « Mentor Carlys » est son nom
PROVISOIRE, accepté par la feuille de route ; le changer un jour ne
changera que des libellés, jamais des identifiants.

Le Mentor n'est pas un écran : c'est une VOIX et une présence.

- Sa voix teinte le coach IA, côté serveur, à chaque tour.
- Il PARLE : son mot, l'aperçu de ses voix, la visite et les réponses du
  coach s'écoutent, à voix haute (section « La voix parlée »).
- Son mot paraît sur l'accueil (section « Pour toi »), à sa voix.
- Il fait visiter l'application, une pièce à la fois.
- Il fête un cap franchi, à sa voix, une seule fois.

## Les deux axes : profil et style, composés, jamais croisés

Le profil Carlys décrit LA PERSONNE (ce qu'il faut privilégier) ; le style
du Mentor décrit LA VOIX (comment le dire). Quatre styles : Bienveillant,
Exigeant, Athlète, Philosophe.

Côté serveur, `mentorVoiceBriefing` (coach.prompt.ts) COMPOSE les deux
briefings purs — `carlysProfileBriefing` + `mentorStyleBriefing` — joints
par une ligne vide : 4 + 4 textes, jamais 16 croisements, sinon chaque
correction se recopierait quatre fois. Les règles des briefings sont
verrouillées par `coach.prompt.spec.ts` : moins de 400 caractères, AUCUN
chiffre (les chiffres viennent des outils), aucun tiret long, aucun nom de
style dans le préfixe partagé (le cache du prompt se fragmenterait en
quatre), chaîne vide quand rien n'est choisi — jamais une voix devinée.

## La voix parlée (3 octobre 2026)

Le style choisissait ce que le Mentor ÉCRIT ; on pouvait le sélectionner, et
rien ne parlait. Il parle désormais, par la synthèse vocale du TÉLÉPHONE
(`flutter_tts` : TextToSpeech d'Android, AVSpeechSynthesizer d'iOS) — hors
ligne, gratuite, et le texte ne quitte pas l'appareil.

- **Une voix par style** (`domain/mentor_voice.dart`, fonction pure) : la
  hauteur et le débit se combinent — Bienveillant chaleureux et posé,
  Exigeant ferme et net, Athlète rapide, Philosophe grave et lent — et un
  « timbre » choisit parmi les voix françaises du téléphone, rangées par
  nom, pour que deux styles proches n'aient pas aussi la même voix. Sans
  style choisi, la voix du moteur au débit normal.
- **Où il parle** : « Écouter » (`MentorSpeakButton`) sur son mot (bandeau
  violet), sur l'exemple de chaque voix (on l'entend AVANT de choisir), sur
  chaque étape de la visite, et sous chaque réponse du coach — à la voix du
  Mentor. Pendant qu'il parle, le même bouton devient « Arrêter ». Une
  seule phrase à la fois (`MentorSpeechController`).
- **De lui-même** : ouvrir sa feuille, c'est venir l'écouter — il dit son
  mot ; choisir une voix, il dit son exemple de la nouvelle voix. Fermer la
  feuille le fait taire. Le réglage local **« À voix haute »** (page
  « Mentor Carlys », actif par défaut) coupe ces lectures
  spontanées ; les boutons, eux, restent. Avec un lecteur d'écran actif, il
  ne parle jamais de lui-même : deux voix se couvriraient.
- **Sans voix française** sur le téléphone, le bouton le dit (« installe-la
  dans ses réglages de synthèse vocale ») au lieu de rester muet ; la
  préparation se retente à la demande suivante. Des voix françaises qui
  exigent le réseau ne comptent pas : plutôt indisponible que du texte
  envoyé en ligne (la politique de confidentialité promet l'appareil seul).
- **La fin d'une phrase** s'attend dans l'adaptateur, sur les signaux du
  moteur (fin, annulation, erreur) ou sur un arrêt — jamais sur
  `awaitSpeakCompletion`, qu'un arrêt ne libère pas sur iOS. Un compteur
  écarte une phrase arrêtée pendant la préparation des voix, ou remplacée.
- **Android 11+** ne laisse voir le moteur de synthèse que s'il est déclaré
  (`<queries>` … `TTS_SERVICE`) : `scripts/android_branding.sh` l'ajoute au
  manifeste engendré.

## La persistance : le même chemin que le profil Carlys

`UserProfile.mentorStyle` (enum `MentorStyle`, nullable, migration
`20260917175451_mentor_style`) → `PATCH /users/me` (DTO `@IsEnum`, contrat
`mentorStyleSchema`) → `presentUser` → `AuthUser.mentorStyle` → mobile
`MentorStyle.fromWire`, qui rend `null` pour toute valeur inconnue : un
serveur plus récent n'a pas le droit de faire planter un ancien client.

Le choix se fait depuis la feuille du Mentor ou sa page de réglages
(Réglages → « Personnaliser le Mentor », route `/mentor`), par la feuille
« La voix du Mentor » à quatre options. Chaque carte (`MentorVoiceCard`)
porte l'image de sa voix, ce qu'elle change, un mot d'exemple tiré de son
catalogue (`mentorWordCatalog`) et, à droite, le rond du choix — coché
« Voix actuelle » pour celle qui parle : on ENTEND la voix avant de la
choisir.

## Les écrans (maquettes d'octobre 2026)

- **La feuille « Mentor Carlys »** (`showMentorSheet`, depuis « Pour toi ») :
  le titre et « UN MOT POUR AVANCER », le bandeau violet profond (`mentorWord`) avec la
  boussole, la cadence (« Le mot de la semaine », « du jour », ou « Il fête
  un cap avec toi »), le mot, la pastille de la voix et « Écouter » ; puis
  la visite guidée et sa voix (`MentorLinkRow`), et la note « Sa voix teinte
  aussi les réponses du Coach IA ».
- **La page « Mentor Carlys »** (`MentorSettingsScreen`) : l'emblème,
  « Personnalise ton accompagnement », sa voix et la visite ; ses
  interventions et « À voix haute » ; la fréquence (Quotidienne,
  Hebdomadaire) et son mot du moment. Interventions coupées, la fréquence
  et le mot laissent place à la carte « Interventions désactivées ».
- **Écarts voulus** : « À voix haute » reste sur la page (la maquette
  l'oublie, la voix parlée existe) ; « Écouter » reste sur chaque voix et
  sur le mot ; la page garde un seul en-tête, interventions actives ou non
  (la maquette en dessine deux) ; elle s'ouvre plein écran comme les
  Réglages, sans barre d'onglets ; les montagnes du bandeau attendent
  leur illustration (aucun modèle ChatGPT de ce compte ne génère d'image
  le 10 octobre 2026, et un décor peint par code est interdit) ; les citations gardent les guillemets français. Écrit au serveur PUIS relu depuis
`AuthUser` : une seule source de vérité, un échec s'affiche sans état faux.

## Le mot du Mentor (accueil)

Une phrase dans « Pour toi », à la voix choisie (voix neutre tant que rien
n'est choisi). Toucher l'entrée ouvre la feuille du Mentor, qui s'ouvre sur
son bandeau (`mentor_bandeau.dart`) : l'identité et le mot du moment posés
sur le dégradé VIOLET de l'application (`cta`) — le dégradé de marque
multicolore reste réservé aux célébrations (règle 9 du CLAUDE.md).

`mentorWord` est une fonction PURE : style + fréquence +
jour civil → le mot, en rotation DÉTERMINISTE par période — au cran
quotidien il change chaque jour, au cran hebdomadaire il tient la semaine.
Aucune date stockée, donc rien à désynchroniser : la même grammaire que la
question du jour.

Les préférences d'intervention (activées ou non, fréquence) sont LOCALES à
l'appareil (`mentor_prefs_store.dart`) : elles règlent quand le Mentor
parle ICI, comme le thème. Défauts : actives, au cran discret
(hebdomadaire) — même règle que les notifications, « jamais réglé vaut
accepté ».

## La visite guidée

Sept étapes (`mentor_tour.dart`) : accueil, entraînement, nutrition,
progrès, Academy, communauté, coach. Un manifeste constant, un état « déjà
vu » local, et RIEN de verrouillé — la même doctrine que le Parcours de
l'Academy. La feuille montre UNE étape à la fois, au-dessus du chemin des
sept pastilles (`mentor_tour_chemin.dart` — vue, courante, à venir ; chaque
étape porte l'icône de sa pièce, table `mentorTourIcons` gardée par le même
test que les routes) : « Aller voir » est
l'ancrage réel (marque vue, ferme, navigue), « Étape suivante » avance sur
place. La visite se rejoue depuis les réglages du Mentor, à volonté.

Le domaine ne connaît AUCUNE route : la table étape → destination vit dans
la présentation (`mentorTourRoutes`), et un test interdit l'étape sans
destination comme la destination orpheline.

## Les célébrations, au franchissement

Quand une récompense vient d'être gagnée, le mot du Mentor devient sa
célébration, à sa voix. Trois gardes, toutes héritées de règles écrites :

- **`EarnedReward.isNew` uniquement** : vrai seulement dans la session du
  franchissement, APRÈS la garde de première lecture du journal — sur un
  appareil neuf, quinze médailles s'inscrivent en silence et le Mentor se
  tait.
- **Dite une fois** : toucher l'entrée marque la récompense « dite »
  (`mentor.celebrations.dites`) et le mot ordinaire reprend la main. Le
  journal des récompenses garde la trace durable ; le Mentor ne garde que
  ce qu'il a déjà dit.
- **Jamais un second score** : le Mentor relaie une récompense existante,
  il n'en crée aucune et ne compte rien (règle de non-concurrence,
  `progression.md`).

## Couverture

- `coach.prompt.spec.ts` : les quatre briefings de style (distincts, sans
  chiffre, sans cadratin), la composition profil + style (les deux, un
  seul, rien), le préfixe partagé sans nom de style.
- `auth.e2e-spec.ts` / `coach.e2e-spec.ts` : PATCH `mentorStyle` (axe
  indépendant, valeur inconnue refusée), le tour du coach qui contient les
  DEUX briefings avec un préfixe intact octet pour octet.
- `mentor_word_test.dart` : mots par voix tous distincts, rotation
  quotidienne/hebdomadaire, célébration par voix, voix neutre sans choix.
- `mentor_tour_test.dart` : manifeste intègre, ordre, étape sautée,
  identifiant retiré ignoré, table des routes complète (tué par mutation
  sur l'ordre).
- `mentor_prefs_test.dart` : défauts sûrs, idempotence, remise à zéro.
- `mentor_providers_test.dart` : interventions coupées = silence (tué par
  mutation), célébration dite une fois, première lecture muette.
- `home_screen_test.dart` : le mot dans « Pour toi », la feuille du
  Mentor, la visite qui s'ouvre et avance.
- `mentor_voice_test.dart` : cinq voix distinctes à l'oreille, réglages
  dans les bornes des moteurs, timbres séparés pour les voix proches.
- `mentor_speech_controller_test.dart` : la voix choisie ou celle de
  l'aperçu, écouter puis arrêter, une phrase qui remplace l'autre, pas de
  voix française → `false` et le silence.
- `flutter_tts_mentor_speaker_test.dart` : voix françaises hors réseau,
  rangées, choisies par timbre ; refus nommé puis nouvel essai.
- `mentor_voice_widgets_test.dart` : « Écouter »/« Arrêter », le message
  sans voix française, la feuille qui dit son mot puis se tait, « À voix
  haute » coupé, lecteur d'écran, réglage écrit sur l'appareil.
- `mentor_settings_screen_test.dart` : la page interventions actives
  (fréquence choisie et écrite, mot cité) et coupées (carte
  « désactivées »), les bascules annoncées au lecteur d'écran, l'entrée des
  Réglages qui ouvre la page, « Voix actuelle » sur la seule voix choisie.
- `coach_reply_footer_test.dart` : « Écouter » sous la réponse du coach,
  jamais sous la question.

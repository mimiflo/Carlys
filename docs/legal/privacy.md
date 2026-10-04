# Politique de confidentialité de Carlys

Dernière mise à jour : 4 octobre 2026.

Carlys est une application mobile de suivi d’entraînement, accompagnée de
quelques pages web (vérification d’adresse, nouveau mot de passe, retours de
paiement et ces textes). Cette politique explique, sans jargon, quelles
données Carlys traite à ton sujet, pourquoi, combien de temps, avec quels
prestataires, et ce que tu peux exiger. Elle est écrite à partir du
fonctionnement réel du service, pas d’un modèle générique.

## 1. Qui est responsable de tes données

Le responsable du traitement est [À COMPLÉTER : raison sociale], dont le
siège est situé [À COMPLÉTER : adresse postale du responsable du traitement].

Pour toute question ou demande liée à tes données, écris à
[À COMPLÉTER : adresse e-mail de contact].

## 2. Les données que Carlys traite

Carlys ne collecte que ce que tu lui donnes, ce que Google ou Apple lui
transmet si tu choisis de te connecter avec eux, et ce qui est nécessaire
pour faire fonctionner le service. Voici l’inventaire complet.

### Ton compte

- Ton adresse e-mail, ton nom d’affichage et, si tu en as un, ton mot de
  passe. Le mot de passe n’est jamais conservé en clair : seule une
  empreinte (Argon2id) est stockée, et personne, pas même nous, ne peut la
  retransformer en mot de passe.
- Un code ami de 8 caractères, généré par Carlys, que tu peux partager pour
  être ajouté sans donner ton adresse e-mail.
- La date de création du compte, son statut (actif, suspendu, supprimé) et la
  date à laquelle ton adresse e-mail a été vérifiée.
- Ta langue et ton fuseau horaire, pour afficher les dates et les séries de
  jours correctement.

### Si tu te connectes avec Google ou Apple

Les boutons « Continuer avec Google » et « Continuer avec Apple » te
connectent sans mot de passe Carlys. Si aucun compte Carlys n’existe encore
à l’adresse que Google ou Apple nous transmet, toucher l’un de ces boutons
crée ton compte, y compris depuis l’écran de connexion.

- **Ce que Google ou Apple nous transmet** : une preuve de connexion signée
  qui contient l’identifiant de ton compte chez eux, ton adresse e-mail, le
  fait qu’ils l’ont vérifiée et, s’ils le fournissent, ton nom. Carlys
  vérifie cette preuve, en retient ce qui suit, et ne la conserve pas.
- **Ce que Carlys conserve** : le fournisseur (Google ou Apple), cet
  identifiant et l’adresse transmise, rattachés à ton compte. À la création
  du compte, ton nom devient ton nom d’affichage ; à défaut, c’est le début
  de ton adresse e-mail. Ton adresse est enregistrée comme vérifiée.
- **Un compte créé ainsi n’a pas de mot de passe.** Tu peux en définir un à
  tout moment avec « Mot de passe oublié ».
- **Si un compte Carlys existe déjà à cette adresse**, Google ou Apple y est
  rattaché. Si ce compte n’avait jamais vérifié son adresse, c’est Google ou
  Apple qui vient de prouver qu’elle est à toi : toutes les sessions
  ouvertes sur ce compte sont déconnectées, son mot de passe est retiré et
  les liens de réinitialisation en cours cessent de valoir. Personne d’autre
  ne garde ainsi l’accès à un compte créé avec ton adresse.
- **Sans adresse vérifiée par Google ou Apple**, rien n’est créé ni
  rattaché.

Le lien avec ton compte Google ou Apple est effacé dès que tu supprimes ton
compte Carlys.

### Tes appareils et tes sessions

- Le nom et la plateforme de l’appareil que tu déclares à la connexion.
- L’adresse IP et la signature technique de l’appareil ou du navigateur
  (user agent) au moment de chaque connexion, ainsi que les dates de
  connexion et de dernière utilisation.

Ces informations servent à te montrer la liste de tes appareils connectés, à
te permettre d’en déconnecter un à distance, et à détecter qu’une session
volée est réutilisée.

### Ton profil physique (facultatif)

Si tu choisis de les renseigner : ton sexe biologique, ta date de naissance,
ta taille, ton niveau d’activité et ton objectif nutritionnel. Ces champs
sont tous facultatifs : sans eux, le rapport métabolique reste simplement
vide.

### Tes choix d’entraînement et de profil (facultatifs)

Si tu les renseignes : le profil Carlys que tu as choisi (Constructeur,
Challenger, Athlète ou Stratège), le style de voix du Mentor, ton objectif
d’entraînement, ton niveau d’expérience, le nombre de séances que tu vises
par semaine et leur durée, et le matériel dont tu disposes. Ils servent à
te parler sur le bon ton et à préparer ton programme.

### Tes mesures corporelles

Les pesées et mesures que tu saisis, avec leur date.

### Ton entraînement

Tes modèles de séance, tes programmes, tes séances réalisées (exercices,
séries, répétitions, charges, durées, notes) et les records personnels que
l’application calcule à la fin de chaque séance.

### Ta nutrition

Les repas que tu enregistres (nom, calories, macronutriments, quantité,
moment de la journée et, quand tu composes un repas, les aliments choisis et
leurs quantités) et les cibles calculées par l’application à partir de ton
profil et de ta dernière pesée : métabolisme de base, dépense estimée,
objectif calorique, macronutriments, indice de masse corporelle et
hydratation. Chercher un aliment n’envoie que les mots tapés : ils ne sont
pas enregistrés avec ton compte, seulement dans les journaux techniques
décrits plus bas, comme toute requête.

### La photo de tes repas (facultative)

Si tu prends ou choisis une photo pour un repas, elle est envoyée à nos
serveurs et conservée avec ce repas, pour que tu la retrouves sur tous tes
appareils. Rien ne t’y oblige : un repas s’enregistre très bien sans photo.

- **Ce qui quitte ton téléphone** : la photo que tu as prise ou choisie, et
  elle seule. Avant l’envoi, ton téléphone la prépare : il la redresse (une
  photo prise téléphone debout reste debout), la réduit à 1 600 pixels sur
  son plus grand côté et la réenregistre en JPEG sans aucune des
  informations que l’appareil y avait inscrites (position, marque et modèle,
  date). Elle ne part qu’au moment où tu enregistres le repas ; si tu
  renonces avant, rien n’est envoyé. Rien d’autre de ta photothèque n’est
  lu ni envoyé.
- **Les autorisations** : l’accès à l’appareil photo n’est demandé que
  lorsque tu touches « Prendre une photo » (il sert aussi à scanner le code
  ami d’un profil). « Choisir dans la galerie » ouvre le sélecteur de ton
  téléphone : Carlys ne reçoit que la photo que tu y touches, sans accès au
  reste de ta photothèque. Tu peux retirer l’accès à l’appareil photo à tout
  moment dans les réglages de ton téléphone.
- **Ce qui est stocké** : l’image seule. Avant tout stockage, Carlys en
  retire toutes les informations que ton téléphone y a inscrites : la
  position GPS du lieu de la prise de vue, la marque et le modèle de
  l’appareil, la date, les légendes et commentaires (ton téléphone les a
  déjà retirées, le serveur s’en assure). Le nom du fichier n’est pas
  conservé non plus. Sur ton téléphone, les copies temporaires que
  l’appareil photo ou la galerie remet à l’application sont effacées dès
  que la photo est préparée, y compris, sous Android, la copie ORIGINALE
  (position comprise) que le sélecteur de la galerie dépose à côté de la
  copie réduite, et la photo affichée n’est gardée qu’en mémoire, le temps
  de l’utilisation de l’application.
- **Qui la voit** : toi, et personne d’autre dans l’application. Elle n’est
  montrée ni à tes amis, ni dans les défis ou la ligue, et elle n’est
  transmise ni au coach IA, ni à aucun autre prestataire (le scan
  d’assiette, ci-dessous, est un envoi à part que tu déclenches toi-même). Elle est rangée à
  part des images publiques de l’application, dans un espace de stockage
  privé que seul le serveur de Carlys peut lire, et qu’il ne te rend qu’à
  toi, après avoir vérifié ton identité. Les personnes qui exploitent le
  serveur peuvent techniquement y accéder, comme au reste de la base de
  données, et ne le font que pour faire fonctionner le service.
- **Quand elle disparaît** : quand tu la remplaces ou la retires, quand tu
  supprimes le repas, et quand tu supprimes ton compte (voir « Combien de
  temps »).

### Le scan d’assiette (facultatif, abonnés)

« Scanner un aliment » envoie la photo de ton assiette pour qu’une
intelligence artificielle reconnaisse les aliments et estime leurs grammes.
Rien ne s’enregistre sans toi : l’écran du repas s’ouvre pré-rempli, tu
corriges, puis tu choisis de l’ajouter ou non au journal.

- **Ce qui quitte ton téléphone** : la photo que tu as prise ou choisie,
  préparée comme celle d’un repas (redressée, sans aucune information
  inscrite par l’appareil) et réduite à 768 pixels sur son plus grand côté.
- **Qui l’analyse** : un modèle de vision ouvert (Qwen3-VL) que Carlys fait
  tourner sur son propre serveur, comme le coach. La photo ne part chez
  aucun prestataire d’intelligence artificielle, et elle n’entre pas dans
  ta conversation avec le coach.
- **Ce qui est gardé** : la photo n’est PAS stockée par le scan. Elle reste
  dans la mémoire du serveur le temps de l’analyse (une à deux minutes en
  général, davantage si d’autres attendent), puis elle est oubliée. Le
  résultat (le nom des aliments vus, leurs grammes estimés et les aliments
  correspondants de la table Ciqual) est gardé une heure au plus, le temps
  que ton téléphone le relise, puis effacé. Si tu ajoutes ensuite le repas
  au journal, sa photo devient celle du repas (section ci-dessus).
- **Combien** : un nombre de scans par jour s’applique à chaque compte
  (remis à zéro à minuit UTC, soit 1 h ou 2 h du matin à Paris) ; un scan
  qui échoue de notre fait (serveur occupé ou en panne) n’est pas compté.

### Ta communauté

Tes demandes d’ami envoyées et reçues, ta liste d’amis, les encouragements
envoyés et reçus, ta participation aux défis collectifs et ce que tu y as
apporté, les défis entre amis que tu crées (leur titre, le mot que tu
adresses à tes invités, ce qu’ils comptent, leur objectif et leur durée) ou
auxquels tu es invité, et ce que tu y apportes, ta place et ton score dans
la ligue pour chaque semaine où tu y as participé, tes réponses aux quiz et
tes réglages de partage (ta progression visible par tes amis, et ta
participation à la ligue).

Qui voit quoi :

- **Tes amis** voient ton nom d’affichage. Si tu partages ta progression
  (réglage activé au départ, que tu peux couper à tout moment), ils voient
  aussi ta série de jours d’entraînement et ton nombre de séances des sept
  derniers jours. Tes séances elles-mêmes, tes charges, tes mesures et tes
  repas ne sont montrés à personne.
- **Un encouragement** est lu par l’ami à qui tu l’envoies, avec ton nom.
- **Une personne à qui tu envoies une demande d’ami** voit ton nom
  d’affichage dans ses demandes reçues, même si elle ne te connaît pas.
- **Toute personne qui connaît ton code ami** peut lire ton nom d’affichage,
  pour vérifier à qui elle s’adresse avant de t’envoyer une demande.
- **Les personnes invitées à un même défi entre amis** voient le nom de
  chacune des autres, sa réponse à l’invitation et ce qu’elle a apporté au
  défi, ainsi que son titre et le mot de la personne qui l’a créé. Il leur
  suffit d’être amies de cette personne : elles ne sont pas forcément amies
  entre elles.
- **La ligue** est FACULTATIVE et se rejoint explicitement : tant que tu n’y
  es pas entrée, rien n’y est compté et personne n’y voit ton nom. Une fois
  entrée, tu es classée chaque semaine dans un groupe de 20 membres de ta
  division : ton nom d’affichage, ton score de la semaine et ton rang sont
  visibles des autres membres de ce groupe qui participent à la ligue, et
  d’eux seuls. Tu en sors quand tu veux : le compte s’arrête aussitôt et ton
  nom disparaît du classement des autres. Ton score de la semaine en cours
  reste enregistré, sans ton nom, pour que les rangs des autres ne bougent
  pas.
- **Une personne que tu bloques**, ou qui te bloque, cesse d’être ton amie,
  ne peut plus te trouver par ton code ami ni t’envoyer de demande ou
  d’encouragement, et ne voit plus ton nom dans le classement de la ligue,
  ni toi le sien. Les défis entre amis font exception : dans un défi où
  cette personne est invitée comme toi, chacune continue de voir le nom de
  l’autre, sa réponse à l’invitation et ce qu’elle y apporte, qu’elle l’ait
  accepté ou non. Seul le défi CRÉÉ par l’une des deux change pour
  l’autre : tant que l’autre n’y a pas accepté, il disparaît de sa liste ;
  si elle y avait déjà accepté, le défi reste lisible, mais le mot de celle
  qui l’a créé n’y est plus montré.

Un refus de demande d’ami n’est jamais notifié à la personne refusée.

### Tes blocages et tes signalements

Si tu bloques quelqu’un, Carlys enregistre ce blocage (qui bloque qui, et
depuis quand) jusqu’à ce que tu le lèves, ou jusqu’à l’effacement définitif
de l’un des deux comptes. La personne bloquée n’en est pas prévenue.

Si tu signales une personne, un encouragement ou un défi entre amis, Carlys
enregistre ton signalement : la raison choisie, tes précisions (500
caractères au plus) et, pour un encouragement ou un défi, une copie de son
texte prise au moment du signalement, qui reste lisible même si le message
est retiré ensuite. Les signalements sont lus par les administrateurs de
Carlys chargés de la modération, qui voient aussi le nom et l’adresse e-mail
de la personne qui signale et de la personne signalée. La personne signalée
n’est pas prévenue. Un signalement est conservé, même une fois traité,
jusqu’à l’effacement définitif de ton compte ou de celui de la personne
signalée.

### Tes notifications

Le jeton d’appareil fourni par Firebase Cloud Messaging quand tu acceptes
les notifications, la session depuis laquelle il a été enregistré, et tes
préférences par famille de notification (demandes d’ami, encouragements,
invitations à un défi).

### Tes conversations avec le coach

Les messages que tu écris au coach, ses réponses, les séances qu’il te
propose, et le volume de texte traité à chaque échange.

### Ton abonnement

Le plan souscrit, son statut, ses dates de période, l’identifiant de
l’abonnement chez le prestataire de paiement et les droits qui en découlent.
Carlys ne voit jamais ton numéro de carte : il est saisi et conservé chez le
prestataire de paiement, jamais chez nous. Chaque avis par lequel le
prestataire de paiement ou le magasin d’applications annonce un changement
de ton abonnement (souscription, renouvellement, résiliation) est aussi
conservé tel qu’il est reçu, pour qu’aucun ne soit appliqué deux fois. Les
autres avis (factures, paiements) ne sont pas conservés.

### Le journal de sécurité

Les événements de sécurité liés à ton compte (connexion réussie ou échouée,
connexion avec Google ou Apple, renouvellement de session, réinitialisation
de mot de passe, vérification d’adresse, suppression de compte, par toi ou
par nous à ta demande écrite, action d’un administrateur sur ton compte)
avec leur date, l’adresse IP, le user agent et un identifiant de requête.
La suppression d’un compte y note aussi combien d’abonnements payés sur le
web ont été résiliés, et si un abonnement pris dans un magasin
d’applications courait encore. Une connexion échouée n’y laisse pas
l’adresse e-mail saisie, seulement une empreinte de cette adresse : une
courte suite de caractères qui permet de reconnaître des tentatives
répétées sur la même adresse, sans l’écrire. Les lignes plus anciennes, qui
pouvaient encore porter l’adresse saisie, en ont été vidées : elles disent
qu’une adresse a été saisie, sans plus dire laquelle. Une action d’un administrateur sur ton compte y
porte l’identifiant technique de ton compte et, s’il en a écrit une, la
raison de sa décision ; le traitement d’un signalement que tu as fait y
porte aussi cet identifiant.

### Les journaux techniques

Chaque requête reçue par le serveur produit une ligne de journal, corrélée
par un identifiant de requête, qui recopie le chemin demandé, recherche
comprise. Les en-têtes d’authentification et les cookies en sont retirés
avant écriture. Quand un envoi d’e-mail ou une tentative de connexion doit
être tracé, seule une empreinte de ton adresse e-mail l’est. Quand un
administrateur cherche ton compte dans l’outil d’administration, par ton
nom ou ton adresse e-mail, sa recherche voyage dans le contenu de sa
requête, jamais dans le chemin demandé : aucun de ces journaux ne la
recopie. Le serveur web qui reçoit les
requêtes tient aussi son propre journal (adresse IP, page demandée avec sa
recherche, date, user agent) : les jetons des liens de vérification et de
réinitialisation y sont masqués. Aucun mot de passe ni jeton ne figure
dans ces journaux.

### Ce que Carlys ne fait pas

Les pages web de Carlys ne déposent aucun cookie et n’embarquent aucun
traceur ni outil de mesure d’audience. L’application ne lit ni tes contacts,
ni ta position. Si tu joins une photo à un repas, la position que ton
téléphone y a inscrite en est retirée avant tout stockage. Carlys ne lit
rien non plus dans le service de santé de ton téléphone (Health Connect sur
Android, Santé sur iOS) : ni pas, ni fréquence cardiaque, ni sommeil.

## 3. Pourquoi Carlys traite ces données

- **Pour fournir le service que tu as demandé** : créer ton compte,
  enregistrer et synchroniser tes séances entre tes appareils, calculer ta
  progression et tes records, gérer ton abonnement. C’est l’exécution du
  contrat qui nous lie.
- **Pour protéger ton compte** : sessions par appareil, adresses IP, journal
  de sécurité et limitation du nombre de tentatives. C’est notre intérêt
  légitime à sécuriser le service, et le tien.
- **Pour les données de santé** (profil physique, mesures corporelles,
  nutrition et photos de repas, conversations avec le coach) : c’est ton
  consentement. Tu les saisis toi-même, elles sont facultatives, et tu peux
  les effacer ou cesser d’utiliser ces fonctions à tout moment.
- **Pour la communauté** : faire fonctionner les amis, les encouragements,
  les défis et la ligue que tu choisis d’utiliser. Ce que chacun y voit de
  toi est détaillé plus haut (« Ta communauté », « Qui voit quoi ») : ta
  série de jours et ton nombre de séances des sept derniers jours, que
  montre le partage de ta progression, ne le sont qu’à tes amis ; en
  revanche, ce que
  tu apportes à un défi entre amis (par exemple ton nombre de séances depuis
  son début, s’il compte les séances) est vu des autres personnes invitées,
  même quand elles ne sont pas tes amies, et ton score de ligue, calculé à
  partir de tes séances, est vu des autres membres de ton groupe. La ligue
  ne compte rien tant que tu n’y es pas entrée.
- **Pour la modération** : traiter les signalements et appliquer les
  blocages. C’est notre intérêt légitime à garder la communauté
  respectueuse, et celui des personnes qui l’utilisent.
- **Pour les notifications** : le jeton d’appareil n’est enregistré que si tu
  acceptes les notifications sur ton téléphone, et chaque famille peut être
  refusée séparément dans l’application. Le refus est appliqué côté serveur,
  avant tout envoi.
- **Pour te contacter** : uniquement des e-mails de service (vérification
  d’adresse, réinitialisation de mot de passe). Carlys n’envoie pas de
  newsletter ni de publicité.

## 4. Le coach IA

Le coach de Carlys est un assistant automatisé fourni par un modèle de
langage ouvert (Qwen3) que Carlys fait tourner **sur son propre serveur**,
celui qui héberge déjà la base de données (voir « Hébergement » plus bas). Il
n’est utilisé que lorsque tu lui écris.

Pour produire la réponse, les éléments suivants sont traités sur ce serveur,
et **aucun n’est transmis à un prestataire d’intelligence artificielle** :

- ton message, les derniers messages de la conversation en cours et le
  résumé des plus anciens (voir plus bas) ;
- le profil Carlys que tu as choisi (Constructeur, Challenger, Athlète ou
  Stratège) et le style de voix que tu as choisi pour le Mentor, sans ton
  nom ni ton adresse e-mail ;
- ton profil d’entraînement : objectif, niveau, nombre et durée de séances
  visés, matériel, et le nom de ton programme actif ;
- et seulement quand le coach en a besoin pour te répondre, les données qu’il
  lit par ses outils : tes modèles de séance, tes dernières séances
  terminées, tes records personnels, ta progression sur une période, tes
  dernières pesées, ton rapport métabolique (sexe, date de naissance,
  taille, dernier poids, niveau d’activité, objectif et cibles calculées) et
  tes repas récents (nom, moment, calories, macronutriments et aliments).
  La photo d’un repas ne lui est jamais transmise.

Le modèle n’apprend pas de tes échanges : ils ne servent jamais à
l’entraîner. Seules les conversations enregistrées par Carlys, décrites
ci-dessous, sont conservées.

Quand une conversation s’allonge, le coach ne relit que ses derniers
messages ; les plus anciens sont résumés par le même modèle, sur le même
serveur (ton objectif, tes préférences, ta progression, ce que le coach t’a
proposé). Ce résumé est rangé avec la conversation et s’efface avec elle.
Pour chaque réponse, Carlys note aussi des mesures techniques, sans le texte
de tes messages : l’heure de la demande, le temps d’attente et de génération,
le volume traité, le serveur qui a répondu, et si la réponse a abouti. Elles
servent à dimensionner le service et s’effacent avec ton compte.

Le coach n’écrit dans ton compte que des séances : chaque séance qu’il te
propose est gardée dans tes modèles, catégorie « Coach », pour que tu la
retrouves, et il en crée une quand tu le lui demandes. Tu peux les modifier
ou les supprimer comme les tiennes ; il ne touche à rien d’autre (ni tes
séances faites, ni tes mesures, ni ton profil). Les conversations sont conservées
sur nos serveurs, jusqu’à l’effacement de ton compte, pour que tu puisses
les relire et les reprendre. L’application te montre tes 30 conversations
les plus récentes, que tu peux toujours relire, même sans abonnement ou
quand le coach est momentanément coupé ; les plus anciennes restent
conservées sans y être listées, et nous t’en donnons une copie si tu la
demandes (voir « Tes droits »). Une copie des derniers messages de ta
dernière conversation reste aussi sur ton téléphone, pour que tu puisses la
relire sans connexion. Elle s’efface quand tu te déconnectes de
l’application, quand tu y supprimes ton compte, ou quand un autre compte s’y
connecte ; si ta session expire ou est fermée à distance, elle reste sur ton
téléphone jusqu’à l’un de ces moments. Sur Android, l’application est exclue
des sauvegardes du téléphone ; sur iPhone, cette copie peut figurer dans ses
sauvegardes, chiffrées par Apple. Écrire au coach demande un abonnement qui
l’inclut. Un plafond quotidien de messages s’applique à chaque compte.

Quand le Mentor ou le coach te parle à voix haute, c’est ton téléphone qui
lit le texte, par sa propre synthèse vocale : rien de plus n’est envoyé, ni à
Carlys ni à un prestataire.

Si Carlys confiait un jour le coach à un prestataire extérieur, cette
politique serait mise à jour, en le nommant, avant que tes messages ne lui
soient envoyés.

## 5. Les autres prestataires

- **Paiement : Stripe.** Quand tu souscris un abonnement, tu es dirigé vers
  une page de paiement Stripe. Stripe reçoit un identifiant technique de ton
  compte Carlys, ainsi que les informations que tu saisis sur sa page
  (adresse e-mail, carte bancaire). Carlys reçoit en retour l’état de
  l’abonnement, jamais ta carte.
- **Connexion : Google et Apple**, seulement si tu choisis de te connecter
  avec eux. Ils savent alors que tu utilises Carlys, et nous transmettent ce
  qui est décrit plus haut (« Si tu te connectes avec Google ou Apple »).
- **Notifications : Firebase Cloud Messaging (Google).** Google reçoit le
  jeton de ton appareil et le contenu de chaque notification envoyée, par
  exemple « Prénom a accepté ta demande d’ami », un encouragement avec le
  prénom de son auteur, ou l’invitation à un défi avec son titre.
- **E-mails de service : [À COMPLÉTER : prestataire d’envoi d’e-mails].** Il
  reçoit ton adresse e-mail et le contenu des e-mails de vérification et de
  réinitialisation.
- **Hébergement : serveur dédié de l’éditeur**, situé
  [À COMPLÉTER : pays d’hébergement du serveur]. La base de données, les
  journaux et les sauvegardes y résident.
- **Copie de secours hors du serveur :
  [À COMPLÉTER : fournisseur du stockage distant et pays, ou retirer ce
  point si aucune copie distante n’est configurée].** Chaque nuit, une
  sauvegarde de la base de données et une copie des images publiques de
  l’application (les photos d’exercices) y sont envoyées, chiffrées avant de
  quitter le serveur : ce prestataire les stocke sans pouvoir les lire. Les
  photos de tes repas n’en font pas partie.
- **Stockage des images.** Les photos d’exercices du catalogue sont servies
  depuis un stockage objet public : elles ne disent rien de toi. Les photos
  que tu joins à tes repas sont rangées à part, dans un stockage objet
  PRIVÉ, sur le même serveur dédié que la base de données : aucune adresse
  publique n’y mène, et seul le serveur de Carlys les lit.

Certains de ces prestataires (Apple, Google, Stripe) peuvent traiter les
données en dehors de l’Union européenne, dans le cadre des garanties
contractuelles qu’ils proposent. [À COMPLÉTER : vérifier le cadre de
transfert applicable à chaque prestataire.]

## 6. Combien de temps

- **Tant que ton compte existe**, toutes les données décrites ci-dessus sont
  conservées : c’est ton historique, et c’est ce qui fait la valeur de
  l’application pour toi.
- **Les liens envoyés par e-mail** expirent vite : 24 heures pour la
  vérification d’adresse, 60 minutes pour la réinitialisation de mot de
  passe. Un lien ne sert qu’une fois. Un nouveau lien de vérification
  annule les précédents ; dès qu’un lien de réinitialisation sert, ou que
  ton mot de passe change, tous ceux qui restaient tombent.
- **Les sessions** expirent après 30 jours sans utilisation, ou immédiatement
  quand tu les déconnectes.
- **Le scan d’assiette** ne garde pas la photo, et son résultat une heure au
  plus (voir « Le scan d’assiette »).
- **Les jetons de notification** sont rattachés à la session qui les a
  enregistrés. Ils sont supprimés quand tu te déconnectes de l’appareil,
  quand cette session est déconnectée à distance ou révoquée (changement ou
  réinitialisation du mot de passe, « déconnecter les autres appareils »,
  réutilisation suspecte d’une session, suspension du compte), et dès que
  Google nous signale qu’ils ne sont plus valables. Quand une session
  expire, plus aucune notification n’est envoyée à ses jetons, et
  l’application efface le sien de ton téléphone.
- **La photo d’un repas** est conservée tant que le repas existe et que tu ne
  l’as pas retirée. Quand tu la remplaces ou la retires, quand tu supprimes
  le repas ou ton compte, elle est effacée du stockage aussitôt, sans
  attendre le délai de purge ci-dessous. Si le stockage ne répond pas à cet
  instant, l’incident est consigné, et l’image est effacée par le nettoyage
  automatique qui repasse chaque jour sur le stockage des photos ; s’il
  échoue lui aussi, l’équipe qui exploite le serveur en est alertée, et il
  recommence toutes les heures jusqu’à y parvenir. D’ici là, l’image reste
  rangée sous l’identifiant de ton compte, mais plus rien dans l’application
  ne la montre ni ne permet de la lire. Les photos de repas ne figurent dans
  aucune sauvegarde : une photo effacée ne survit nulle part.
- **Quand tu supprimes ton compte**, ton abonnement payé sur le web, chez
  Stripe, est d’abord résilié, tout de suite : plus aucun prélèvement ne
  suit. Si Stripe ne confirme pas cette résiliation, rien n’est supprimé,
  l’application te le dit, et tu peux réessayer un instant plus tard. Un
  abonnement pris dans l’App Store ou le Play Store, lui, ne peut être
  résilié que dans le magasin : Carlys ne peut pas le faire à ta place, et
  l’application te rappelle de le résilier là-bas, sans quoi le magasin
  continuera de te prélever. Ton compte est ensuite désactivé
  immédiatement : plus personne ne peut s’y connecter, et sont effacés
  aussitôt tes sessions, ton adresse e-mail, ton nom, ton code ami, ta date
  de naissance, ton sexe, ta taille, tes jetons de notification, le lien
  avec ton compte Google ou Apple et les photos de tes repas. Tu quittes au
  même instant la ligue, les défis entre amis et le fil des
  encouragements : ton nom disparaît du classement de la ligue (ton score
  de la semaine reste compté, sans ton nom, pour que les rangs des autres
  ne bougent pas), les défis entre amis que tu as lancés sont effacés, ta
  participation aux défis des autres en est retirée (un défi déjà fini est
  d’abord réglé avec ton score, pour que son résultat ne change pas ; un
  défi en cours où plus personne ne reste face à la personne qui l’a lancé
  est annulé), et les encouragements que tu as envoyés disparaissent. Ton adresse redevient libre pour un nouveau compte. Le
  reste (séances, modèles et programmes, records, mesures, repas,
  conversations avec le coach, liste d’amis, encouragements reçus,
  participation aux défis collectifs, scores de ligue, réponses aux quiz,
  blocages, signalements, abonnement résilié) reste enregistré sous un
  identifiant technique, sans plus rien qui te nomme, pendant 30 jours : ce
  délai laisse le temps de corriger une erreur ou de traiter une
  contestation. Au bout de ces 30 jours, un traitement automatique qui passe
  chaque jour efface tout cela définitivement.
- **Pour un effacement définitif sans attendre ces 30 jours**, écris-nous
  depuis l’adresse e-mail de ton compte, AVANT de le supprimer : une fois
  ton adresse effacée, plus rien ne nous permet de retrouver ton compte.
  Pour vérifier que la demande vient bien de toi, nous t’écrivons d’abord à
  l’adresse de ton compte un code à nous renvoyer : sans lui, nous ne
  touchons à rien. À réception de ce code, nous supprimons ton compte pour
  toi, exactement comme le fait l’application (abonnement payé sur le web
  résilié, sortie de la ligue, des défis et du fil des encouragements),
  puis nous l’effaçons définitivement, tout de suite. Si tu le supprimes
  toi-même entre-temps, nous l’effaçons
  définitivement dès que c’est fait. Une demande reçue après la suppression
  ne peut plus être rattachée à ton compte : l’effacement définitif se fait
  alors au bout des 30 jours.
- **Les avis de paiement** (voir « Ton abonnement ») sont conservés avec ton
  compte et effacés avec lui. Un avis qui ne désigne aucun compte, par
  exemple un achat fait dans un magasin d’applications avant toute
  connexion à Carlys, n’a pu être appliqué à personne : il est conservé 90
  jours, le temps de vérifier s’il devait l’être, puis effacé par le même
  traitement quotidien.
- **Le journal de sécurité** n’est pas effacé avec ton compte. À
  l’effacement définitif, ses lignes perdent leur lien avec ton compte, qui
  n’existe plus. Elles gardent leur date, l’adresse IP, le user agent et ce
  qui est décrit plus haut (« Le journal de sécurité ») : l’empreinte d’une
  adresse saisie lors d’une connexion échouée, jamais l’adresse elle-même,
  et, pour une action d’un administrateur ou un signalement traité,
  l’identifiant technique de ton ancien compte, qui ne renvoie plus à
  aucune donnée. Il est conservé, comme les journaux techniques,
  [À COMPLÉTER : durée de conservation des journaux de sécurité et
  techniques], puis supprimé.
- **Les sauvegardes** de la base de données sont faites chaque nuit et
  gardées environ deux semaines (16 jours au plus), sur le serveur comme
  dans la copie de secours hors du serveur. Avant chaque mise à jour du
  service, une sauvegarde de plus est prise, et gardée environ un mois (32
  jours au plus). Une donnée effacée de la base, celles d’un compte
  supprimé comprises, peut donc survivre dans ces sauvegardes jusqu’à 16
  jours après son effacement, ou jusqu’à 32 jours dans une sauvegarde
  d’avant mise à jour. Une vieille sauvegarde n’est effacée qu’une fois la
  suivante réussie, pour ne jamais laisser le service sans sauvegarde : si
  la sauvegarde d’une nuit échoue, l’équipe qui exploite le serveur en est
  alertée, et ces durées s’allongent d’autant, jusqu’à la prochaine
  sauvegarde réussie. Les sauvegardes ne sont lues que pour remettre le
  service en état après un incident.

## 7. Tes droits

Tu peux, à tout moment :

- **Accéder** à tes données : l’application te montre déjà l’essentiel
  (profil, séances, mesures, amis, abonnement). Pour une copie complète et
  lisible, écris-nous.
- **Les rectifier** : ton profil, tes mesures, tes séances et tes repas se
  modifient directement dans l’application, et la photo d’un repas se
  remplace ou se retire à tout moment.
- **Supprimer ton compte** : depuis l’application, dans Profil → Réglages
  (le rouage) → Compte → « Supprimer mon compte ». Ton mot de passe t’est
  demandé pour confirmer, et l’écran récapitule ce qui est effacé et ce qui
  reste. La désactivation est immédiate et irréversible ; ton abonnement
  payé sur le web est résilié automatiquement, un abonnement pris dans
  l’App Store ou le Play Store se résilie dans le magasin (voir « Combien
  de temps »). Un compte créé avec Google ou Apple n’a pas de mot de
  passe : définis-en un d’abord avec « Mot de passe oublié » (le lien
  arrive à l’adresse de ton compte), puis supprime ton compte. Tu peux
  aussi nous écrire à l’adresse de contact, depuis l’adresse e-mail de ton
  compte : une fois renvoyé le code que nous t’écrivons à cette adresse
  pour vérifier que la demande vient de toi, nous le supprimons pour toi,
  avec le même effet, puis l’effaçons définitivement sans attendre les 30
  jours.
- **Retirer ton consentement** pour les données de santé : efface ton profil
  physique et tes mesures, ou cesse d’utiliser la nutrition et le coach.
- **T’opposer** à un traitement fondé sur notre intérêt légitime, ou en
  demander la limitation.
- **Obtenir la portabilité** de tes données dans un format structuré.

Nous répondons dans un délai d’un mois. Si tu estimes que tes droits ne sont
pas respectés, tu peux saisir l’autorité de contrôle compétente :
[À COMPLÉTER : autorité de contrôle compétente, par exemple la CNIL].

## 8. Âge minimum

Carlys s’adresse aux personnes d’au moins 15 ans. En dessous de cet âge,
l’inscription nécessite l’accord d’un titulaire de l’autorité parentale.
Carlys ne vérifie pas l’âge à l’inscription ; si nous apprenons qu’un compte
appartient à une personne plus jeune sans cet accord, nous le désactivons.

## 9. Comment tes données sont protégées

- Mot de passe stocké sous forme d’empreinte Argon2id, jamais en clair.
- Sessions courtes renouvelées par un jeton tournant ; la réutilisation d’un
  ancien jeton révoque toute la session.
- Chiffrement en transit (TLS) sur tous les environnements distants.
- Limitation du nombre de tentatives de connexion et de demandes sensibles.
- Accès des administrateurs restreint par permission et intégralement
  journalisé : chaque action sur un compte est tracée avec son auteur.
- Journaux techniques expurgés des en-têtes d’authentification, des
  cookies, des jetons des liens envoyés par e-mail et des adresses e-mail,
  y compris celle qu’un administrateur cherche dans l’outil
  d’administration (voir « Les journaux techniques »).
- Sauvegardes chiffrées avant de quitter le serveur.

## 10. Modifications de cette politique

Si cette politique change de façon substantielle, la nouvelle version est
publiée à cette adresse avec sa date, et l’application te le signale.

## 11. Contact

[À COMPLÉTER : raison sociale], [À COMPLÉTER : adresse postale du
responsable du traitement], [À COMPLÉTER : adresse e-mail de contact].

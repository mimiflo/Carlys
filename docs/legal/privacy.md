# Politique de confidentialité de Carlys

Dernière mise à jour : 3 septembre 2026.

Carlys est une application mobile de suivi d'entraînement, accompagnée de
quelques pages web (vérification d'adresse, nouveau mot de passe, retours de
paiement et ces textes). Cette politique explique, sans jargon, quelles
données Carlys traite à ton sujet, pourquoi, combien de temps, avec quels
prestataires, et ce que tu peux exiger. Elle est écrite à partir du
fonctionnement réel du service, pas d'un modèle générique.

## 1. Qui est responsable de tes données

Le responsable du traitement est [À COMPLÉTER : raison sociale], dont le
siège est situé [À COMPLÉTER : adresse postale du responsable du traitement].

Pour toute question ou demande liée à tes données, écris à
[À COMPLÉTER : adresse e-mail de contact].

## 2. Les données que Carlys traite

Carlys ne collecte que ce que tu lui donnes ou ce qui est nécessaire pour
faire fonctionner le service. Voici l'inventaire complet.

### Ton compte

- Ton adresse e-mail, ton nom d'affichage et ton mot de passe. Le mot de
  passe n'est jamais conservé en clair : seule une empreinte (Argon2id) est
  stockée, et personne, pas même nous, ne peut la retransformer en mot de
  passe.
- Un code ami de 8 caractères, généré par Carlys, que tu peux partager pour
  être ajouté sans donner ton adresse e-mail.
- La date de création du compte, son statut (actif, suspendu, supprimé) et la
  date à laquelle ton adresse e-mail a été vérifiée.
- Ta langue et ton fuseau horaire, pour afficher les dates et les séries de
  jours correctement.

### Tes appareils et tes sessions

- Le nom et la plateforme de l'appareil que tu déclares à la connexion.
- L'adresse IP et la signature technique de l'appareil ou du navigateur
  (user agent) au moment de chaque connexion, ainsi que les dates de
  connexion et de dernière utilisation.

Ces informations servent à te montrer la liste de tes appareils connectés, à
te permettre d'en déconnecter un à distance, et à détecter qu'une session
volée est réutilisée.

### Ton profil physique (facultatif)

Si tu choisis de les renseigner : ton sexe biologique, ta date de naissance,
ta taille, ton niveau d'activité, ton objectif nutritionnel et le profil
Carlys que tu as choisi. Ces champs sont tous facultatifs : sans eux, le
rapport métabolique reste simplement vide.

### Tes mesures corporelles

Les pesées et mesures que tu saisis, avec leur date.

### Ton entraînement

Tes modèles de séance, tes programmes, tes séances réalisées (exercices,
séries, répétitions, charges, durées, notes) et les records personnels que
l'application calcule à la fin de chaque séance.

### Ta nutrition

Les repas que tu enregistres (calories) et les cibles calculées par
l'application à partir de ton profil et de ta dernière pesée : métabolisme de
base, dépense estimée, objectif calorique, macronutriments, indice de masse
corporelle et hydratation.

### Ta communauté

Tes demandes d'ami envoyées et reçues, ta liste d'amis, les encouragements
envoyés et reçus, ta participation aux défis, tes réponses aux quiz et ton
réglage de partage de progression.

### Tes notifications

Le jeton d'appareil fourni par Firebase Cloud Messaging quand tu acceptes
les notifications, et tes préférences par famille de notification (demandes
d'ami, encouragements).

### Tes conversations avec le coach

Les messages que tu écris au coach, ses réponses, les séances qu'il te
propose, et le volume de texte traité à chaque échange.

### Ton abonnement

Le plan souscrit, son statut, ses dates de période, l'identifiant de
l'abonnement chez le prestataire de paiement et les droits qui en découlent.
Carlys ne voit jamais ton numéro de carte : il est saisi et conservé chez le
prestataire de paiement, jamais chez nous.

### Le journal de sécurité

Les événements de sécurité liés à ton compte (connexion réussie ou échouée,
renouvellement de session, réinitialisation de mot de passe, vérification
d'adresse, suppression de compte, action d'un administrateur sur ton compte)
avec leur date, l'adresse IP, le user agent et un identifiant de requête.

### Les journaux techniques

Chaque requête reçue par le serveur produit une ligne de journal, corrélée
par un identifiant de requête. Les en-têtes d'authentification et les
cookies en sont retirés avant écriture ; aucun mot de passe ni jeton n'y
figure jamais.

### Ce que Carlys ne fait pas

Les pages web de Carlys ne déposent aucun cookie et n'embarquent aucun
traceur ni outil de mesure d'audience. L'application ne lit ni tes contacts,
ni ta position, ni les données de santé de ton téléphone.

## 3. Pourquoi Carlys traite ces données

- **Pour fournir le service que tu as demandé** : créer ton compte,
  enregistrer et synchroniser tes séances entre tes appareils, calculer ta
  progression et tes records, gérer ton abonnement. C'est l'exécution du
  contrat qui nous lie.
- **Pour protéger ton compte** : sessions par appareil, adresses IP, journal
  de sécurité et limitation du nombre de tentatives. C'est notre intérêt
  légitime à sécuriser le service, et le tien.
- **Pour les données de santé** (profil physique, mesures corporelles,
  nutrition, conversations avec le coach) : c'est ton consentement. Tu les
  saisis toi-même, elles sont facultatives, et tu peux les effacer ou cesser
  d'utiliser ces fonctions à tout moment.
- **Pour la communauté** : ton nom d'affichage, ta série de jours et, si tu
  l'as activé, ta progression sont visibles de tes amis uniquement. Un refus
  de demande d'ami n'est jamais notifié à la personne refusée.
- **Pour les notifications** : le jeton d'appareil n'est enregistré que si tu
  acceptes les notifications sur ton téléphone, et chaque famille peut être
  refusée séparément dans l'application. Le refus est appliqué côté serveur,
  avant tout envoi.
- **Pour te contacter** : uniquement des e-mails de service (vérification
  d'adresse, réinitialisation de mot de passe). Carlys n'envoie pas de
  newsletter ni de publicité.

## 4. Le coach IA et les données envoyées à un prestataire

Le coach de Carlys est un assistant automatisé fourni par un modèle de
langage. Il n'est utilisé que lorsque tu lui écris.

À chaque message, les éléments suivants sont transmis au prestataire
**Anthropic, PBC** (API Claude) pour produire la réponse :

- ton message et l'historique de la conversation en cours ;
- le profil Carlys que tu as choisi (Constructeur, Challenger, Athlète ou
  Stratège), sans ton nom ni ton adresse e-mail ;
- et seulement quand le coach en a besoin pour te répondre, les données qu'il
  lit par ses outils : tes modèles de séance, tes dernières séances
  terminées, tes records personnels, ta progression sur une période, tes
  dernières pesées et ton rapport métabolique (sexe, date de naissance,
  taille, dernier poids, niveau d'activité, objectif et cibles calculées).

Le coach ne peut rien écrire dans ton compte : les séances qu'il propose ne
sont enregistrées que si tu les acceptes. Les conversations sont conservées
sur nos serveurs pour que tu puisses les reprendre. Un plafond quotidien de
messages s'applique à chaque compte.

Le prestataire traite ces données pour le seul compte de Carlys, dans le
cadre de ses conditions commerciales. [À COMPLÉTER : vérifier et résumer les
conditions de traitement du contrat Anthropic (durée de conservation,
non-utilisation pour l'entraînement des modèles, localisation).]

## 5. Les autres prestataires

- **Paiement : Stripe.** Quand tu souscris un abonnement, tu es dirigé vers
  une page de paiement Stripe. Stripe reçoit un identifiant technique de ton
  compte Carlys, ainsi que les informations que tu saisis sur sa page
  (adresse e-mail, carte bancaire). Carlys reçoit en retour l'état de
  l'abonnement, jamais ta carte.
- **Notifications : Firebase Cloud Messaging (Google).** Google reçoit le
  jeton de ton appareil et le contenu de chaque notification envoyée, par
  exemple « Prénom a accepté ta demande d'ami » ou un encouragement avec le
  prénom de son auteur.
- **E-mails de service : [À COMPLÉTER : prestataire d'envoi d'e-mails].** Il
  reçoit ton adresse e-mail et le contenu des e-mails de vérification et de
  réinitialisation.
- **Hébergement : serveur dédié de l'éditeur**, situé
  [À COMPLÉTER : pays d'hébergement du serveur]. La base de données, les
  journaux et les sauvegardes y résident.
- **Stockage des médias.** Les photos d'exercices du catalogue sont servies
  depuis un stockage objet. Aucune donnée personnelle n'y est stockée :
  Carlys ne te demande jamais de photo.

Certains de ces prestataires (Anthropic, Google, Stripe) peuvent traiter les
données en dehors de l'Union européenne, dans le cadre des garanties
contractuelles qu'ils proposent. [À COMPLÉTER : vérifier le cadre de
transfert applicable à chaque prestataire.]

## 6. Combien de temps

- **Tant que ton compte existe**, toutes les données décrites ci-dessus sont
  conservées : c'est ton historique, et c'est ce qui fait la valeur de
  l'application pour toi.
- **Les liens envoyés par e-mail** expirent vite : 24 heures pour la
  vérification d'adresse, 60 minutes pour la réinitialisation de mot de
  passe. Un lien ne sert qu'une fois.
- **Les sessions** expirent après 30 jours sans utilisation, ou immédiatement
  quand tu les déconnectes.
- **Les jetons de notification** sont supprimés quand tu te déconnectes de
  l'appareil, et dès que Google nous signale qu'ils ne sont plus valables.
- **Quand tu supprimes ton compte**, il est désactivé immédiatement : toutes
  tes sessions sont révoquées, plus personne ne peut s'y connecter, et ton
  identité (adresse e-mail, nom, code ami) n'est plus accessible depuis
  l'application. Les données rattachées au compte sont ensuite conservées au
  plus [À COMPLÉTER : délai de purge après suppression, par exemple 30 jours]
  puis effacées ou rendues anonymes. Si tu veux un effacement immédiat,
  demande-le à l'adresse de contact.
- **Le journal de sécurité et les journaux techniques** sont conservés
  [À COMPLÉTER : durée de conservation des journaux de sécurité et
  techniques], puis supprimés.

## 7. Tes droits

Tu peux, à tout moment :

- **Accéder** à tes données : l'application te montre déjà l'essentiel
  (profil, séances, mesures, amis, abonnement). Pour une copie complète et
  lisible, écris-nous.
- **Les rectifier** : ton profil, tes mesures et tes séances se modifient
  directement dans l'application.
- **Supprimer ton compte** : écris-nous à l'adresse de contact. La
  désactivation est immédiate et irréversible. Dès que l'application
  proposera la suppression directement dans tes réglages, elle produira
  exactement le même effet.
- **Retirer ton consentement** pour les données de santé : efface ton profil
  physique et tes mesures, ou cesse d'utiliser la nutrition et le coach.
- **T'opposer** à un traitement fondé sur notre intérêt légitime, ou en
  demander la limitation.
- **Obtenir la portabilité** de tes données dans un format structuré.

Nous répondons dans un délai d'un mois. Si tu estimes que tes droits ne sont
pas respectés, tu peux saisir l'autorité de contrôle compétente :
[À COMPLÉTER : autorité de contrôle compétente, par exemple la CNIL].

## 8. Âge minimum

Carlys s'adresse aux personnes d'au moins 15 ans. En dessous de cet âge,
l'inscription nécessite l'accord d'un titulaire de l'autorité parentale.
Carlys ne vérifie pas l'âge à l'inscription ; si nous apprenons qu'un compte
appartient à une personne plus jeune sans cet accord, nous le désactivons.

## 9. Comment tes données sont protégées

- Mot de passe stocké sous forme d'empreinte Argon2id, jamais en clair.
- Sessions courtes renouvelées par un jeton tournant ; la réutilisation d'un
  ancien jeton révoque toute la session.
- Chiffrement en transit (TLS) sur tous les environnements distants.
- Limitation du nombre de tentatives de connexion et de demandes sensibles.
- Accès des administrateurs restreint par permission et intégralement
  journalisé : chaque action sur un compte est tracée avec son auteur.
- Journaux techniques expurgés des en-têtes d'authentification et des
  cookies.

## 10. Modifications de cette politique

Si cette politique change de façon substantielle, la nouvelle version est
publiée à cette adresse avec sa date, et l'application te le signale.

## 11. Contact

[À COMPLÉTER : raison sociale], [À COMPLÉTER : adresse postale du
responsable du traitement], [À COMPLÉTER : adresse e-mail de contact].

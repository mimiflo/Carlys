# ADR 0014 — Coach IA : proposer et créer une séance, garanti par l'orchestration

## Statut

Acceptée — 2026-10-02. Complète l'ADR 0013 (la passerelle) : le modèle reste
Qwen3-4B sur processeur ; ce qui change, c'est QUI décide qu'un tour doit
finir par une séance.

## Contexte

Signalé cinq fois par le propriétaire, captures à l'appui (2 octobre 2026) :
« Il ne propose pas de séance, il ne crée rien dans mon appli, il parle
juste. » Qwen3-4B comprenait la demande, lisait les exercices… puis
répondait en texte (« Pour travailler les pecs, tu peux commencer par des
pompes… »), sans appeler `propose_session`. Rien ne permettait non plus de
CRÉER une séance : « Ok crée-la » recevait « Bien sûr, je te prépare ça »,
et rien n'était écrit.

Le circuit était : utilisateur → modèle → le modèle décide s'il appelle
l'outil. Consignes, ordre de proposer après coup (« occasion d'agir »),
lecture d'avance des exercices : chacun améliorait la moyenne (jusqu'à deux
cartes sur trois), aucun ne la garantissait, parce que la décision restait
au modèle.

## Décision

**L'orchestration décide ce que le tour DOIT produire, et refuse de le
terminer sans.** Le modèle garde ce qu'il fait bien : choisir et expliquer.

1. **Résolveur d'intention** (`application/coach-intent.ts`), avant tout
   appel au modèle. Des règles déterministes, testées sur 75 formulations
   (`test/fixtures/coach-intents.json`), qui combinent les signaux du message
   (verbe d'action et son objet, muscles, temps disponible, forme de la
   question) et le CONTEXTE du fil (la proposition des derniers échanges,
   la séance demandée plus haut, la frustration qui redit une demande) :
   `GENERAL_CHAT`, `KNOWLEDGE`, `DATA_QUERY`, `WORKOUT_ADVICE`, `PROGRAM`,
   `WORKOUT_PROPOSAL_REQUIRED`, `WORKOUT_MODIFICATION_REQUIRED`,
   `WORKOUT_CREATION_REQUIRED`, `CLARIFICATION_REQUIRED`.
2. **Proposer, garanti.** Pour une séance exigée, le serveur lit d'avance
   profil, records, dernières séances et exercices des muscles demandés, ne
   garde que le faisable, puis demande au modèle UN choix à sortie contrainte
   (`response_format: json_schema`, exercices désignés par alias pris dans la
   liste). Après le modèle, `CoachActions.settle` applique le contrat : sans
   proposition VALIDÉE, le serveur compose seul ; sans rien de faisable, la
   raison métier est dite. Un texte seul n'est jamais rendu pour une séance
   exigée — quel que soit le fournisseur.
3. **Créer, garanti.** Une séance créée est un MODÈLE de séance (la seule
   séance durable qu'on puisse écrire sans la lancer), enregistré par
   `CoachWorkoutCreator` sous l'identifiant de sa proposition : la créer deux
   fois redonne le même, jamais réécrit. « Ok crée-la » est servi SANS le
   modèle (`CoachActionTurn`) : la proposition des derniers échanges est
   relue et enregistrée ; « Crée-moi une séance jambes » est composée puis
   enregistrée dans le même tour. La phrase « C'est enregistré » n'est écrite
   qu'APRÈS l'écriture en base ; la preuve archivée est
   `CoachMessage.createdTemplateId` (migration `coach_seance_enregistree`),
   rendue `createdWorkout` à l'appli, qui montre la carte « Séance
   enregistrée ».
4. **Proposer ≠ créer.** Une proposition n'écrit rien : carte, « Voir la
   séance », lancement par la personne. Seule une demande de création écrit.
   *Amendé le 3 octobre 2026* : toute proposition validée est désormais
   GARDÉE d'office (modèle `fromCoach`, onglet « Coach » de « Mes modèles »),
   pour ne pas se perdre avec son fil. La création reste distincte dans la
   réponse — seule elle dit « C'est enregistré » — et ne fait plus que
   confirmer le même modèle.

## Alternatives écartées

- **Davantage de consignes au modèle** : essayé (couverture des muscles,
  première personne, « ne recopie pas la séance »), utile, jamais suffisant.
- **Relancer le modèle avec un ordre interne** quand il n'a rien proposé :
  essayé (« occasion d'agir »), deux cartes sur trois, et un texte écrit
  avant la carte qui en décrivait une autre. La sortie contrainte rend
  l'ordre inutile pour les séances ; le repli serveur couvre le reste.
- **Un classifieur d'intention par le modèle** : 10 à 20 s de plus par tour
  sur le processeur du serveur, pour un jugement moins sûr que des règles
  testées.
- **Créer une séance « en cours »** pour « Mets-la pour aujourd'hui » : une
  séance naît sur l'appareil quand on la commence (hors ligne d'abord) ; le
  serveur n'a pas de séance planifiée. Le modèle de séance est ce qui existe.

## Conséquences

- Une séance exigée finit TOUJOURS par une carte valide ou une raison métier ;
  une création, par une écriture prouvée ou sa raison métier.
- La route sans flux a une échéance de 50 s : sur processeur, le modèle y est
  presque toujours coupé, et c'est le serveur qui compose. L'appli utilise la
  route en flux (10 min).
- « Mets-la pour aujourd'hui » enregistre la séance dans les modèles ; il n'y
  a pas de planification au jour (à décider si le besoin se confirme).
- Les règles du résolveur se maintiennent comme un jeu de tests : une
  formulation ratée s'ajoute aux fixtures, puis la règle se corrige.

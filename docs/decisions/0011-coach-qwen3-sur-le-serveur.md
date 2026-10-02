# ADR 0011 — Coach IA : Qwen3-4B sur notre serveur, servi par Ollama

## Statut

Acceptée — 2026-09. Remplace la décision 2 de l'ADR 0010 (Mistral Free mode
en production) ; le reste de l'ADR 0010 (le fournisseur est un réglage, toute
panne est un 503, un 503 sans consommation rend le message) tient toujours.

## Contexte

Le 28 septembre 2026, Mistral Free mode a refusé chaque demande du coach :
429 « rate limit exceeded » sur `mistral-small-latest`, même à un unique
« Bonjour » envoyé à la main. Des comptes gratuits rapportaient au même
moment une allocation nulle sur ce modèle (`x-ratelimit-limit-req-minute: 0`)
et un service sur les Ministral. Passé à un Ministral, le coach a répondu une
fois, puis est redevenu « momentanément indisponible ». Une offre gratuite
n'est garantie par personne, et celle-ci se rétrécissait sans préavis.

Le propriétaire a demandé le 29 septembre 2026 de ne plus dépendre d'un
fournisseur : faire tourner le modèle nous-mêmes, sur le serveur.

## Décision

1. **Qwen3-4B, variante « instruct » 2507 (`qwen3:4b-instruct-2507-q4_K_M`, ≈ 2,5 Go
   quantifié), servi par Ollama**, dans le service `ollama` de
   `infrastructure/server/compose.yml`, image épinglée (`ollama/ollama:0.34.4`).
   Étiquette EXACTE : l'étiquette courte `qwen3:4b` peut désigner une
   version qui « réfléchit » avant de répondre (plus lente, des centaines de
   jetons de plus) et changer de cible en amont. La variante instruct ne
   réfléchit pas : aucun réglage de réflexion à envoyer.
2. **Éteint par défaut, et absent** : le service vit sous le profil compose
   `ollama`, que `dc` (`scripts/server/_common.sh`) n'active que si le `.env`
   porte `CARLYS_OLLAMA_REPLICAS=1`, avec les deux variables qui y envoient
   l'API (`COACH_API_BASE_URL=http://ollama:11434/v1`, `COACH_MODEL`). À zéro
   exemplaire sans profil, `up -d` aurait quand même tiré son image
   (≈ 3,75 Go compressés) sur chaque serveur. `COMPOSE_PROFILES` du `.env`
   ne suffit pas : mesuré, le `--profile` que `dc` passe le fait ignorer.
   Aucun port publié : seule l'API lui parle, par le réseau compose ; ni clé
   ni https, l'adresse est interne.
3. **Le modèle ne se télécharge que s'il manque** au volume `ollama-data`, au
   démarrage du conteneur ; un téléchargement raté arrête le conteneur
   (sortie 1), que Docker relance et que la supervision compte, au lieu
   d'une boucle silencieuse. `deploy.sh` tire l'image d'Ollama AVANT toute
   migration, comme celles de MinIO.
4. **Réglages d'Ollama** : modèle gardé en mémoire (`OLLAMA_KEEP_ALIVE=-1`),
   contexte de 8 192 jetons (les consignes et outils en font ≈ 3 000, un
   contexte trop court les tronquerait en silence), une réponse à la fois
   (`OLLAMA_NUM_PARALLEL=1`), priorité processeur relative de 256
   (`cpu_shares`, 1024 pour les autres) pour que l'API et PostgreSQL passent
   devant. Plafond mémoire de recette : 6 Go.

## Raisons

- Plus de quota imposé ni de facture, plus de changement d'offre subi.
- Les messages du coach, qui portent des données de santé (poids, repas,
  douleurs), ne quittent plus le serveur : plus de sous-traitant pour le
  coach, plus d'accord de traitement à obtenir, plus de question de lieu de
  calcul. Quatre marqueurs `[À COMPLÉTER]` de la politique de confidentialité
  disparaissent avec Mistral.
- Aucun code nouveau côté coach : le client compatible OpenAI de l'ADR 0010
  parlait déjà à un Ollama interne sans clé (prévu et testé).
- Qwen3 appelle des outils (Ollama l'annonce « tools ») et existe en 4B, la
  plus grande taille raisonnable sur un processeur.

## Avantages

- Gratuit, sans limite de débit autre que la machine.
- Données de santé traitées sur place ; textes légaux plus simples.
- Revenir à Mistral ou à Anthropic reste un réglage (textes légaux d'abord).

## Inconvénients

- **La vitesse dépend du processeur du serveur.** L'ADR 0010 relevait 1,5 à
  4,5 minutes par réponse pour un modèle de 8 milliards de paramètres sur un
  petit serveur ; 4B va environ deux fois plus vite, soit de l'ordre de 45 s
  à plus de 2 minutes sur cette base. Le propriétaire l'a essayé sur le
  serveur le 29 septembre 2026 et l'a jugé assez rapide ; la mesure du guide
  (étape 5) reste à relever. Le serveur laisse 50 s à un tour
  (`COACH_TURN_DEADLINE_MS`), nginx 60 s, l'application 65 s : si la mesure
  le demande, ces trois délais bougent ensemble, ou le modèle rétrécit.
  *Relevé le 30 septembre 2026 : 8,2 jetons/s en écriture. Les réponses qui
  relisaient des séances s'arrêtaient net à 50 s ; un tour EN FLUX a
  désormais 3 minutes (`COACH_REQUEST_TIMEOUT_MS`), nginx et l'application
  tenus éveillés par un battement toutes les 15 s — voir `coach-ia.md`,
  « Latence ». Le tour d'un bloc garde ses 50 s.*
  *2 octobre 2026 : ces 3 minutes coupaient encore les longues réponses
  (2 048 jetons ≈ 4 min). Le tour en flux a un PLAFOND de 10 minutes ; la
  panne se mesure au silence du flux (60 s), et une réponse coupée reprend
  — `coach-ia.md`, « Réponses coupées : la reprise ».*
- **Une réponse à la fois**, et l'attente dans la file d'Ollama compte dans
  l'échéance du tour (10 min en flux depuis le 2 octobre 2026) : deux
  personnes qui écrivent en même temps, la seconde attend, et peut recevoir
  « momentanément indisponible » si la première réponse est longue.
- Un petit modèle suit moins bien les consignes : les garde-fous du prompt
  (santé, planchers caloriques, dopants) se revérifient par les vingt
  questions du guide avant toute ouverture.
- ≈ 4 à 5 Go de mémoire vive et ≈ 6 Go de disque (image et modèle) pris sur
  la machine qui porte déjà la recette et la production ; les deux
  environnements allumés, le modèle deux fois.
- Un contexte de 8 192 jetons peut déborder sur une très longue
  conversation (consignes, vingt messages d'historique, résultats d'outils,
  réponse) : à surveiller dans les jetons du journal « Tour de coach ».

## Conséquences

- `infrastructure/server/compose.yml` : service `ollama` (profil `ollama`)
  et volume `ollama-data` ; `compose_test.sh` vérifie qu'il est absent sans
  son profil, sans port publié, sous la priorité processeur de l'API, et
  plafonné en recette.
- Gabarits `.env` : bloc « Coach IA » réécrit, `CARLYS_OLLAMA_MEM_LIMIT`.
- `scripts/server/_common.sh` (`dc`, `coach_local_actif`) et `deploy.sh` :
  profil `ollama` selon le `.env`, image tirée avant les migrations ;
  `supervision_test.sh` et `compose_test.sh` le vérifient.
- `docs/legal/privacy.md` et `terms.md` : le coach tourne sur notre serveur,
  aucun prestataire d'IA ne reçoit les messages. L'admin, qui publie ces
  pages, doit être redéployée.
- Pas à pas : `docs/deployment/mise-en-route-serveur.md`, « Coach IA sur le
  serveur ».

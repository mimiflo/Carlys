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

1. **Qwen3-4B (`qwen3:4b`, ≈ 2,5 Go quantifié), servi par Ollama**, dans le
   service `ollama` de `infrastructure/server/compose.yml`, image épinglée
   (`ollama/ollama:0.34.4`).
2. **Éteint par défaut** (`CARLYS_OLLAMA_REPLICAS=0`) : on l'allume dans le
   `.env` de l'environnement, avec les trois variables qui y envoient l'API
   (`COACH_API_BASE_URL=http://ollama:11434/v1`, `COACH_MODEL=qwen3:4b`,
   `COACH_REASONING_EFFORT=none`). Aucun port publié : seule l'API lui
   parle, par le réseau compose ; ni clé ni https, l'adresse est interne.
3. **Le modèle se télécharge tout seul** au démarrage du conteneur, dans le
   volume `ollama-data` ; la sonde ne passe au vert qu'une fois le modèle
   présent, et la supervision relance un conteneur resté « unhealthy »,
   donc retente un téléchargement raté.
4. **La réflexion de Qwen3 est coupée** : Ollama l'active d'office sur un
   modèle qui la sait faire, et elle ajoute des centaines de jetons avant
   chaque réponse. Le champ `reasoning_effort: "none"` de l'interface
   compatible OpenAI la coupe ; il n'est envoyé que si
   `COACH_REASONING_EFFORT` est posé, parce que les Ministral de Mistral le
   refusent (400).
5. **Réglages d'Ollama** : modèle gardé en mémoire (`OLLAMA_KEEP_ALIVE=-1`),
   contexte de 8 192 jetons (les consignes et outils en font ≈ 3 000, un
   contexte trop court les tronquerait en silence), une réponse à la fois
   (`OLLAMA_NUM_PARALLEL=1`). Plafond mémoire de recette : 6 Go.

## Raisons

- Plus de quota imposé ni de facture, plus de changement d'offre subi.
- Les messages du coach, qui portent des données de santé (poids, repas,
  douleurs), ne quittent plus le serveur : plus de sous-traitant pour le
  coach, plus d'accord de traitement à obtenir, plus de question de lieu de
  calcul. Quatre marqueurs `[À COMPLÉTER]` de la politique de confidentialité
  disparaissent avec Mistral.
- Aucun code nouveau côté coach : le client compatible OpenAI de l'ADR 0010
  parlait déjà à un Ollama interne sans clé (prévu et testé). Seul
  `COACH_REASONING_EFFORT` s'ajoute.
- Qwen3 appelle des outils (Ollama l'annonce « tools ») et existe en 4B, la
  plus grande taille raisonnable sur un processeur.

## Avantages

- Gratuit, sans limite de débit autre que la machine.
- Données de santé traitées sur place ; textes légaux plus simples.
- Revenir à Mistral ou à Anthropic reste un réglage (textes légaux d'abord).

## Inconvénients

- **La vitesse dépend du processeur du serveur, et elle n'est pas encore
  mesurée.** L'ADR 0010 relevait 1,5 à 4,5 minutes par réponse pour un modèle
  de 8 milliards de paramètres sur un petit serveur ; 4B va environ deux fois
  plus vite. Le serveur laisse 50 s à un tour (`COACH_TURN_DEADLINE_MS`),
  nginx 60 s, l'application 65 s : si la mesure le demande, ces trois délais
  bougent ensemble, ou le modèle rétrécit.
- Un petit modèle suit moins bien les consignes : les garde-fous du prompt
  (santé, planchers caloriques, dopants) se revérifient par les vingt
  questions du guide avant toute ouverture.
- ≈ 4 à 5 Go de mémoire vive pris sur la machine qui porte déjà la recette et
  la production ; les deux environnements allumés, deux fois.
- Une réponse à la fois : deux personnes qui écrivent ensemble attendent
  l'une après l'autre.

## Conséquences

- `infrastructure/server/compose.yml` : service `ollama` et volume
  `ollama-data` ; `scripts/server/tests/compose_test.sh` vérifie qu'il est
  éteint par défaut, sans port publié, et plafonné en recette.
- Gabarits `.env` : bloc « Coach IA » réécrit, `CARLYS_OLLAMA_MEM_LIMIT`.
- API : `COACH_REASONING_EFFORT` (schéma, configuration, client, tests).
- `docs/legal/privacy.md` et `terms.md` : le coach tourne sur notre serveur,
  aucun prestataire d'IA ne reçoit les messages. L'admin, qui publie ces
  pages, doit être redéployée.
- Pas à pas : `docs/deployment/mise-en-route-serveur.md`, « Coach IA sur le
  serveur ».

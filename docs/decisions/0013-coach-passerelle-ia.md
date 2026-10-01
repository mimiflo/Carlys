# ADR 0013 — Coach IA : une passerelle devant le modèle (file, workers, annulation)

## Statut

Acceptée — 2026-09-30. Complète l'ADR 0011 (le modèle reste Qwen3-4B, sur nos
machines) et l'ADR 0012 (la réponse reste en flux SSE).

## Contexte

Le propriétaire veut que « plusieurs utilisateurs puissent utiliser le coach
en même temps sans surcharger le serveur », en gardant SON modèle, et pouvoir
passer ensuite d'une machine à plusieurs (cartes graphiques, serveurs) sans
toucher à l'application mobile.

Ce qui existait : l'API NestJS appelait Ollama directement, derrière un port
unique (`CoachModelPort`). Ollama sérialisait tout seul (`OLLAMA_NUM_PARALLEL=1`)
dans une file interne, invisible et non bornée : dix personnes, et la dixième
attendait une réponse que l'échéance du tour coupait avant qu'elle commence.
Aucune limite par minute, aucune annulation (un écran fermé laissait la
génération tourner jusqu'au bout), un seul Ollama possible.

Le serveur actuel n'a **pas de carte graphique** : le modèle tourne sur le
processeur, ≈ 8 jetons/s en écriture (mesuré le 30 septembre 2026).

## Décision

1. **La passerelle vit DANS l'API**, module `coach` — pas un service de plus.
   L'API a déjà l'authentification, le droit au coach, le quota, Redis et
   PostgreSQL ; un « ai-gateway » séparé n'ajouterait qu'un saut réseau et un
   déploiement. Les **workers** sont les Ollama : le service `ollama` du
   `compose.yml`, et demain d'autres machines.
2. **Le port reste la frontière.** `CoachModelPort` est l'« AIProvider » ;
   le client compatible OpenAI est le fournisseur local, le client Anthropic
   un fournisseur cloud. `CoachGateway` est l'« AIService » : aucune route ne
   touche plus le modèle sans elle.
3. **File et concurrence dans Redis**, parce que l'API peut tourner en
   plusieurs exemplaires (`CARLYS_API_REPLICAS`) : un compteur en mémoire
   laisserait N exemplaires lancer N générations. Un script Lua atomique tient
   trois ensembles triés : les générations en cours (bail renouvelé, qui
   expire seul si l'exemplaire meurt), la file (ordre d'arrivée), et la
   dernière présence de chaque attente (une attente qui ne se manifeste plus
   depuis 30 s est abandonnée et retirée). Premier arrivé, premier servi,
   tous exemplaires confondus. File pleine : **503 `SERVICE_BUSY`** tout de
   suite, jamais une attente sans fin.
4. **Plusieurs workers : le moins chargé, et retrait temporaire.**
   `COACH_WORKER_URLS` liste les adresses (défaut : `COACH_API_BASE_URL`).
   Chaque tour prend le worker sain qui a le moins de générations en cours ;
   une panne (réseau, 5xx) le met de côté `COACH_WORKER_COOLDOWN_MS`, et la
   tentative suivante part sur un autre. Ajouter une carte graphique =
   ajouter une adresse et relever `COACH_MAX_CONCURRENT_REQUESTS`.
5. **Annuler, c'est arrêter.** Une déconnexion (écran fermé, bouton
   « Arrêter », réseau coupé) abandonne l'appel au worker : Ollama arrête de
   générer quand sa connexion tombe. Le tour est noté `CANCELLED`. C'est un
   revirement de l'ADR 0012, où le tour continuait pour s'archiver : sur un
   processeur partagé, une génération que personne ne lira vole la place de
   la suivante.
6. **Limites par personne, toutes réglables** : messages par minute, une
   génération à la fois, taille du message, messages d'historique relus,
   jetons de sortie, échéances. Toujours sur l'identité Carlys, jamais
   l'adresse IP.
7. **Contexte construit, pas recopié** (`CoachContextBuilder`) : consignes
   (préfixe commun, caché par Ollama), profil d'entraînement condensé et voix
   du mentor (bloc par utilisateur), résumé des anciens échanges, derniers
   messages, question. Les données détaillées restent derrière les outils de
   lecture, consultées à la demande.
8. **Mémoire résumée en arrière-plan** : quand les messages non résumés
   dépassent la fenêtre, un résumé (objectif, préférences, progression,
   décisions) en absorbe la moitié la plus ancienne. Il est écrit par le
   modèle **seulement si la file est vide**, et il cède sa place dès
   qu'une personne y entre. Borné (taille, durée), local seulement, relu
   comme une donnée et non comme une consigne. L'historique part de la fin
   du résumé : il avance par paliers au lieu de glisser, et Ollama ne relit
   que la fin de chaque tour (29 s → 7 s de lecture par tour, mesuré le
   1er octobre 2026).
9. **Le quota se décompte après la file** : refusé par la file ou annulé en
   attente, un message n'a rien coûté.
10. **Chaque génération laisse une ligne** (`CoachGeneration`) : identifiants,
   instants, statut, jetons, worker. Aucun contenu de conversation.
11. **Repli cloud prévu, éteint** : `COACH_CLOUD_FALLBACK=false` par défaut.
    Allumé, il ne sert qu'avec `ANTHROPIC_API_KEY` posée, et seulement après
    la mise à jour des textes légaux (voir `coach-ia.md`).

## Conséquences

- Le premier goulot reste le calcul du modèle ; la passerelle ne le rend pas
  plus rapide, elle le rend **prévisible** : un nombre fixe de générations,
  une file visible (« 2 personnes avant toi »), un refus propre au-delà.
- `COACH_MAX_CONCURRENT_REQUESTS` doit égaler la capacité réelle des workers
  (somme de leurs `OLLAMA_NUM_PARALLEL`). Trop haut, Ollama remet sa propre
  file invisible derrière la nôtre.
- Le benchmark (`coach-bench`) mesure la capacité d'une machine ; c'est lui,
  pas une estimation, qui fixe les réglages.
- L'application mobile ne connaît ni les workers ni la file : elle reçoit
  `queued`, `delta`, `done` ou `error`. Ajouter des machines ne la change pas.

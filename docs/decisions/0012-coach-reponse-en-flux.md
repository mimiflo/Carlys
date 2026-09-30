# ADR 0012 — Coach IA : la réponse s'écrit en direct (SSE)

## Statut

> **Complétée par l'ADR 0013** (30 septembre 2026) : une connexion fermée
> ARRÊTE désormais la génération (elle ne continue plus pour s'archiver),
> et le flux gagne les évènements `queued` et `started`.

Acceptée — 2026-09. Tranche la décision ouverte n° 1 de
`docs/product/coach-ia.md` (« streaming en v1 ou en v2 ») : maintenant.

## Contexte

Depuis l'ADR 0011, le coach tourne sur notre serveur (Qwen3-4B sur le
processeur, sans carte graphique). Une réponse met plusieurs dizaines de
secondes à s'écrire, et l'écran n'en montrait rien : trois points, puis la
réponse d'un bloc. Le 29 septembre 2026, le propriétaire a cru à une panne
(« ça met les … et rien d'autre »), puis a demandé qu'on voie la réponse
s'écrire, avec un signe que le coach réfléchit, « un peu comme Claude ».

Ollama sait diffuser (`stream: true`, SSE compatible OpenAI) ; ce qui manquait
était le relais jusqu'au téléphone.

## Décision

1. **Une route de plus, pas une route changée** :
   `POST /api/v1/coach/conversations/:id/messages/stream`. Même corps, mêmes
   règles (droit, quota, rejeu idempotent, 409, 404) que la route sans flux,
   qui reste pour les versions de l'appli déjà installées.
2. **Server-Sent Events** : `delta` (`{ text }`) à chaque morceau, puis `done`
   (l'enveloppe de succès habituelle, même `CoachReply`), ou `error`
   (l'enveloppe d'erreur habituelle). Le texte **archivé** est celui de
   `done` : ce qui s'est affiché en route n'est qu'un aperçu.
3. **Les en-têtes ne partent qu'au premier évènement** (`common/http/sse.ts`).
   Tout refus survenu avant (403, 429, 404, 409, fournisseur tombé avant le
   premier mot) garde son vrai statut HTTP. Après, `AllExceptionsFilter`
   écrit l'erreur comme dernier évènement du flux.
4. **Le port du modèle gagne `onText`**, facultatif. Le client compatible
   OpenAI demande alors `stream: true` et recompose la réponse ordinaire
   (`chat-completion-stream.ts`) : UNE seule boucle d'outils, flux ou pas. Un
   flux fermé sans `[DONE]` ni `finish_reason` est une panne (c'est la seule
   trace qu'Ollama laisse d'une erreur en cours de génération). Le client
   Anthropic ignore `onText` : la réponse arrive d'un bloc, par `done`.
5. **Un tour à la fois par question** : un verrou Redis (`coach:turn:<id>`,
   levé à la fin, expirant seul après l'échéance du tour) refuse en 409 un
   renvoi arrivé pendant que la réponse s'écrit encore. Sans lui, un flux
   coupé puis renvoyé comptait deux fois le quota, appelait deux fois le
   modèle et archivait deux réponses.
6. **Personne ne retient le flux** : l'API pose `X-Accel-Buffering: no`, que
   Nginx applique et, grâce à `proxy_pass_header`, transmet à gra6.
7. **Mobile** : la question s'affiche aussitôt ; une bulle « Réfléchit… »
   (trois points animés, immobiles si le système réduit les animations)
   attend le premier mot, puis la réponse s'allonge à mesure. Le client
   quitte le fil ? Le serveur finit le tour et l'archive ; la même question
   renvoyée rend la réponse archivée.

## Alternatives écartées

- **WebSocket** : bidirectionnel pour un besoin qui ne l'est pas, une
  seconde pile de connexion, d'authentification et de relais Nginx.
- **Modifier la route existante** : casserait les versions déjà installées,
  qui attendent du JSON.
- **Interroger le serveur à intervalles** : plus de requêtes, plus de
  latence, et un état de génération à stocker quelque part.

## Inconvénients

- Une erreur après le premier mot n'a plus de statut HTTP propre : le client
  doit lire l'évènement `error` (les deux lecteurs du dépôt le font).
- Le texte d'un tour d'outils intermédiaire (« je regarde tes séances… »)
  s'affiche en route puis disparaît si le modèle ne le reprend pas : la
  réplique archivée le remplace.
- Si gra6 bufferise malgré l'en-tête, la réponse arrive d'un bloc à la fin :
  rien ne casse, on revient simplement au comportement d'avant.

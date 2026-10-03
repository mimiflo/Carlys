# ADR 0010 — Fournisseur du coach IA : un réglage, Mistral gratuit par défaut

## Statut

Acceptée — 2026-09. Sa décision 2 (Mistral Free mode en production) est
remplacée par l'ADR 0011 (Qwen3-4B sur notre serveur) : le Free mode a
refusé toutes les demandes le 28 septembre 2026. Le reste tient.

**Mise à jour du 3 octobre 2026.** Le propriétaire garde son modèle, et lui
seul : le client Anthropic, la variable `ANTHROPIC_API_KEY` et la dépendance
`@anthropic-ai/sdk` sont retirés. Il ne reste qu'un fournisseur, nos workers,
par le client compatible OpenAI ; sans `COACH_API_BASE_URL` et `COACH_MODEL`,
le coach est indisponible (503). Ce qui suit est l'historique de la décision.

## Contexte

Le coach IA ne parlait qu'à Anthropic, par son SDK, dans un seul fichier
(`anthropic.client.ts`) derrière le port `CoachModelPort`. Chaque tour coûte
de l'ordre d'un à deux centimes : une facture pour le propriétaire, qui a
demandé le 27 septembre 2026 un coach **gratuit pour lui** (le coach reste
réservé aux abonnés).

Les options étudiées, sources relues le 27 septembre 2026 :

- **Mistral AI, offre « Free mode »** : API ouverte sans carte bancaire
  (« API access is enabled by default with no credit card required. Usage and
  rate limits apply. »), format Chat Completions compatible OpenAI, appels
  d'outils pris en charge, société française, données stockées dans l'UE par
  défaut, entraînement désactivable (Admin > Privacy). Limites non publiées,
  visibles une fois connecté.
- **Cloudflare Workers AI** : gratuit, mais environ 29 messages par jour pour
  toute l'application avec un modèle de taille comparable.
- **Ollama sur le serveur** (Ministral 3 8B) : aucune donnée ne sort, mais 1,5
  à 4,5 minutes par réponse sur le processeur d'un petit serveur.
- **Écartées** : Gemini gratuit (réservé hors EEE, Suisse et Royaume-Uni par
  ses conditions), GitHub Models (retiré), Groq et OpenRouter (plafonds trop
  bas, hébergement hors UE).

Deux défauts existants pesaient aussi : une erreur du SDK Anthropic n'était
pas une `HttpException` et sortait en **500**, alors que la documentation
promettait un 503 ; et un échec du fournisseur **consommait** un message du
quota quotidien de la personne, qui n'avait pourtant rien reçu.

## Décision

1. **Le fournisseur est un réglage, choisi par une seule variable.**
   `COACH_API_BASE_URL` posée : un client **compatible OpenAI**
   (`openai-compatible.client.ts`, `fetch` natif, aucune dépendance) avec
   `COACH_API_KEY` et `COACH_MODEL`. Absente : le client Anthropic, inchangé
   dans sa forme, avec `ANTHROPIC_API_KEY` (`COACH_MODEL` facultatif,
   `claude-opus-5` par défaut). Pas de `COACH_PROVIDER` : aucune combinaison
   incohérente possible. Toutes ces variables sont facultatives ; un réglage
   incomplet donne un 503, jamais un refus de démarrer.
2. **En production : Mistral, `mistral-small-latest`, Free mode**, adresse
   documentée `https://api.mistral.ai/v1`, entraînement désactivé dans la
   console avant le premier vrai message, paiement à l'usage laissé
   désactivé. L'adresse `https://api.eu.mistral.ai/v1` (documentation
   « Regional inference ») garantit en plus un calcul dans l'UE et l'AELE,
   au tarif multiplié par 1,1 ; son ouverture au Free mode n'est pas
   documentée, le guide dit comment l'essayer.
3. **Toute panne du fournisseur est un 503** (`SERVICE_UNAVAILABLE`), pour
   les deux clients. Un 429 du fournisseur (quota GLOBAL) n'est jamais relayé
   tel quel : le téléphone afficherait « ta limite du jour ». Le client
   compatible OpenAI réessaie deux fois un 429 ou un 5xx ; une seule échéance
   de 50 s couvre le tour entier, sous les 60 s de nginx.
4. **Un 503 du fournisseur survenu avant toute consommation rend le message
   au quota** de la personne (`CoachQuota.refundIfUnavailable`), trois fois
   par jour au plus. Chaque client lève une `CoachProviderUnavailableException`
   qui porte les jetons déjà consommés : un tour tombé après un appel servi
   (tour d'outils) garde son décompte, et s'écrit au journal « Tour de coach
   interrompu » avec ces jetons. Le décompte reste fait AVANT l'appel,
   atomiquement : c'est ce qui tient le plafond sous des envois simultanés ;
   décompter après succès laisserait passer N envois parallèles.

## Raisons

- Le port existait pour cela : la logique métier (outils, validation,
  quota, prompt) ne dépend d'aucun fournisseur, et les tests passent par un
  faux.
- **Un seul client compatible OpenAI sert trois fournisseurs** (Mistral,
  Cloudflare, Ollama par son adresse `/v1`) : le plan B d'un hébergement sur
  le serveur, ou d'un secours, ne demande aucun code.
- `fetch` natif plutôt que le SDK de Mistral : un seul `POST`, comme le
  paiement Stripe (`stripe-form-request.ts`), et aucune dépendance ajoutée.
- Restituer plutôt que décompter après succès : même sûreté sous
  concurrence, pour un `DECR` de plus.

## Avantages

- Plus de facture d'IA pour le propriétaire.
- Données stockées dans l'UE, chez une société française, entraînement
  refusé.
- Revenir à Anthropic, ou passer à un modèle sur le serveur, ne demande
  aucun code. Mais pour Anthropic, qui calcule aux États-Unis, les textes
  légaux passent d'abord : `privacy.md` (Anthropic PBC nommé, remis parmi les
  traitements hors de l'Union européenne) et `terms.md` mis à jour, admin
  redéployée, et seulement ensuite les variables. La politique promet d'être
  à jour AVANT que les messages partent chez un autre prestataire.
- Le 500 d'une panne du fournisseur est corrigé, et une panne qui n'a rien
  consommé ne coûte plus de message (trois fois par jour au plus).

## Inconvénients

- **Une offre gratuite n'est garantie par personne.** Mistral la présente
  comme faite pour l'essai ; elle peut se réduire sans préavis. Le volume
  mensuel épuisé, le coach répond 503 jusqu'au mois suivant.
- **Les règles d'usage de Mistral interdisent les « conseils liés à la
  santé »** : la question est posée par écrit au support avant l'ouverture
  aux vrais utilisateurs ; en cas de refus, retour à Anthropic (textes
  légaux d'abord, voir plus haut) ou modèle sur le serveur.
- **L'annexe de l'accord de traitement de Mistral (DPA) déclare « None » pour
  les catégories particulières de données** (article 9 du RGPD), alors que
  poids, rapport métabolique, repas et douleurs décrites sont des données de
  santé. La même demande écrite au support pose la question : l'accord les
  couvre-t-il pour cet usage, ou faut-il un avenant ? Un marqueur
  `[À COMPLÉTER]` de `privacy.md` attend la réponse, et l'image admin de
  production refuse de se construire tant qu'il reste.
- Un modèle plus petit suit moins bien les consignes : le prompt gagne des
  garde-fous explicites (texte brut, planchers caloriques de l'application,
  trouble alimentaire, dopants et médicaments), chacun testé. Le refus appris
  par le modèle d'Anthropic n'est plus là pour les doubler.
- Pas de cache de prompt explicite : `cacheReadTokens` vaut souvent 0, sans
  que cela signale un préfixe cassé.
- La boucle d'outils est écrite deux fois, une par format d'échange. À
  extraire au troisième format, pas avant.
- Une panne du fournisseur avant toute consommation ne coûte plus de
  message, dans la limite de trois par personne et par jour : au-delà, le
  décompte reprend, sans quoi qui insiste pendant une panne (ou la provoque
  en saturant les limites partagées du Free mode) appellerait le fournisseur
  sans fin.

## Conséquences

- Variables : `COACH_API_BASE_URL`, `COACH_API_KEY`, `COACH_MODEL`
  (désormais facultatif), commentées dans les trois gabarits.
- `docs/legal/privacy.md` et `docs/legal/terms.md` nomment Mistral AI, le
  prestataire réellement configuré ; quatre marqueurs restent à compléter
  par le propriétaire (date de désactivation de l'entraînement, lieu de
  calcul, durée de conservation, couverture des données de santé par l'accord
  de traitement). L'admin, qui publie ces pages, doit être redéployée.
- Pas à pas du propriétaire : `docs/deployment/mise-en-route-serveur.md`,
  « Coach IA gratuit avec Mistral ».
- Côté mobile, l'envoi d'un message attend 65 s (`coachReplyTimeout`) au
  lieu des 20 s du client partagé, sur cette seule route : sans ce délai,
  une réponse lente s'afficherait « hors ligne ».

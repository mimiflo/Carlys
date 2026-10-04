# ADR 0015 — Scan d'assiette : le modèle de vision reconnaît, la base CIQUAL calcule

## Statut

Acceptée — 2026-10-04. S'appuie sur l'ADR 0011 (notre modèle sur notre
serveur) et l'ADR 0013 (la passerelle du coach : workers, file, créneaux).

## Contexte

Le propriétaire veut « un scan d'aliment par IA » : photographier son
assiette et retrouver le repas rempli. Un lecteur de code-barres (Open Food
Facts) a été livré puis retiré le 4 octobre 2026 : ce n'était pas la demande.
Deux contraintes déjà actées cadrent la solution : aucun prestataire d'IA
extérieur (ADR 0011, repli Anthropic retiré le 3 octobre), et aucun service
payant sans accord.

Le serveur n'a pas de carte graphique. Banc du 4 octobre 2026 sur quatre
photos de repas, processeur 4 cœurs, `qwen3-vl:4b-instruct` (Ollama), image
réduite :

| Photo | Durée | Ce que le modèle a vu |
| --- | --- | --- |
| Déjeuner | 130 s (chargement compris) | poulet 150 g, riz 120 g, brocoli 100 g : juste |
| Petit-déjeuner | 78 s | yaourt, myrtilles, granola : juste |
| Dîner | 125 s | saumon, brocoli, haricots verts justes ; « carottes râpées » pour de la patate douce |
| Collation | 85 s | banane juste ; « purée » pour du beurre de cacahuète |

Dix aliments sur douze : assez pour PRÉ-REMPLIR, pas pour enregistrer seul.
La variante « réflexion » (`qwen3-vl:4b`) était plusieurs fois plus lente
pour rien de mieux.

## Décision

1. **Le modèle reconnaît, la base calcule.** Le modèle de vision ne rend que
   des noms d'aliments et des grammes (sortie JSON contrainte par schéma,
   relue sans confiance : 8 aliments au plus, 1 à 2 000 g, noms nettoyés et
   bornés). Chaque nom est rapproché de la table CIQUAL
   (`FoodsService.closest` : tous les mots, puis en retirant le dernier mot
   jusqu'au premier seul). Aucune valeur nutritionnelle ne vient du modèle.
2. **Rien ne s'écrit sans la personne.** Le résultat ouvre l'écran
   « Nouveau repas » pré-rempli (aliments, grammes, nom, photo jointe) ; elle
   corrige, puis enregistre ou renonce. Ce qui n'est pas dans la base est
   nommé, à ajouter à la main.
3. **Les mêmes workers que le coach, la même file.** `MealVisionClient`
   appelle `/chat/completions` (API compatible OpenAI) d'un worker du pool ;
   le créneau se prend par `CoachGateway.withSlot`, comme un tour du coach :
   une analyse et une réponse du coach ne se font jamais concurrence sur le
   même processeur. Modèle : `COACH_VISION_MODEL` ; absent, le scan répond
   503 et le coach n'en dépend pas.
4. **En fond, relu par l'appareil.** `POST /nutrition/meal-scans` (202,
   identifiant né sur l'appareil, idempotent) lance l'analyse et rend le
   scan `PENDING` ; `GET /nutrition/meal-scans/:id` le relit jusqu'à `DONE`
   ou `FAILED`. Le scan vit une heure dans Redis (résultat seulement, jamais
   la photo), partagé par tous les exemplaires de l'API ; un scan resté
   `PENDING` au-delà de l'échéance (file, puis 4 min d'analyse au plus,
   `VISION_TIMEOUT_MS`, et 30 s de marge) est rendu `FAILED`, quota rendu une
   fois (API relancée en cours de route).
5. **Bornes.** Réservé à l'entitlement du coach (`ai_coaching`) ; quota
   quotidien par compte (`COACH_MEAL_SCANS_PER_DAY`, 10 par défaut), rendu
   quand le scan échoue de notre fait (file pleine, worker en panne, API
   relancée), GARDÉ quand le worker refuse l'image (4xx) : la renvoyer en
   boucle coûterait sinon zéro ; 10 envois par minute ; la photo suit les
   règles de celle d'un repas (JPEG prouvé par ses octets, 5 Mio au plus),
   et en plus celles du décodeur des workers : JPEG de base ou progressif en
   8 bits, 4 096 px de côté au plus (415 sinon, avant la file). L'appareil
   la réduit à 768 px avant l'envoi.
6. **Un worker n'est écarté que pour une panne** (réseau, 5xx) : ni un
   refus d'image (4xx), ni un délai dépassé sur un processeur lent ne le
   mettent en quarantaine pour tout le monde.

## Alternatives écartées

- **Un service de vision hébergé** (API d'un grand fournisseur) : plus juste
  et plus rapide, mais payant et hors de notre serveur ; contraire à
  l'ADR 0011 et à la règle « aucun service payant sans accord ».
- **Le modèle donne aussi les calories** : il les inventerait. La table
  CIQUAL est la seule source de chiffres du journal, avec sa mention.
- **Une requête qui attend le résultat** : une à deux minutes dépassent ce
  qu'une requête tient derrière nginx, et une coupure réseau perdrait tout.
- **Le code-barres** : livré puis retiré, ce n'était pas la demande.

## Inconvénients

- **Lent sur processeur** : une à deux minutes, davantage si le coach
  travaille ; l'écran le dit et montre le temps écoulé.
- **Mémoire** : le modèle de vision pèse ≈ 3,3 Go. Avec
  `OLLAMA_MAX_LOADED_MODELS=1`, un scan évince le coach, rechargé au message
  suivant (quelques secondes) ; à 2, les deux restent chargés (≈ 6 Go).
- **Quitter l'écran n'arrête pas l'analyse** : le serveur la finit (le
  quota est compté), et le créneau de la personne reste pris jusque-là ; un
  message du coach ou un nouveau scan attend son tour, avec un message qui
  le dit. Pas d'annulation pour l'instant : à ajouter si les échanges le
  demandent (`DELETE …/meal-scans/:id`).
- **Erreurs d'aliment** : environ un sur six au banc. La revue humaine est
  obligatoire, et le rapprochement CIQUAL peut lui-même choisir un voisin.

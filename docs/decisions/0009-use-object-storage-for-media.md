# ADR 0009 — Stockage objet pour les médias, administrés depuis le back-office

## Statut

Acceptée — 2026-08

## Contexte

Le catalogue d'exercices doit être illustré : une photo par mouvement
aujourd'hui, un maillage 3D animable demain, éventuellement une vidéo de
démonstration. Trois propriétés distinguent ces fichiers de tout ce que le
projet manipulait jusqu'ici :

- **Le volume.** Quelques centaines de fichiers de plusieurs centaines de
  kilo-octets, contre quelques kilo-octets pour l'ensemble des lignes de la
  base. Un maillage 3D se compte en méga-octets.
- **La cadence de changement.** Une photo est remplacée parce qu'elle est ratée,
  parce que le matériel a changé, parce qu'un nouveau mouvement entre au
  catalogue — sans rapport avec le rythme des livraisons applicatives.
- **Le producteur.** Ces fichiers ne sont pas écrits par des développeurs. Ils
  arrivent de la personne qui tient le catalogue.

Trois hébergements étaient possibles : embarqués dans l'application mobile
(`assets/`), stockés en base (colonne binaire), ou déposés dans un stockage
objet. Les vignettes des groupes musculaires, elles, sont bien restées dans
`assets/` : douze fichiers, 163 Kio au total, qui ne changent pas plus souvent
que la charte graphique.

## Décision

Tout média du catalogue — **photo, maillage 3D, vidéo** — est déposé par
l'administration dans un **stockage objet compatible S3** (MinIO en
développement, S3 ou équivalent en production) et servi aux applications par
son URL publique. La base ne conserve qu'une ligne `MediaAsset` décrivant
l'objet, et l'exercice ne référence que cette ligne.

Aucun média du catalogue n'est embarqué dans l'application mobile, écrit en dur
dans le code, ni stocké en base.

## Raisons

- **Ajouter une photo ne demande aucune livraison.** Une image embarquée
  n'existe qu'après publication sur les magasins d'applications et mise à jour
  par l'utilisateur — soit des jours, pour les seuls qui mettent à jour. Le
  stockage objet rend la photo visible à la requête suivante.
- **Le poids de l'application n'augmente pas avec le catalogue.** Trois cents
  photos embarquées, ce sont des dizaines de méga-octets imposés à tous, y
  compris pour les exercices jamais consultés.
- **C'est le rôle d'un stockage objet** : servir des fichiers immuables, en
  masse, avec cache HTTP long et mise en réseau de diffusion possible plus tard
  sans rien changer côté API.
- **Le dépôt est un acte d'administration**, donc soumis au RBAC de l'Étape 7
  (`media:write`, `media:read`) et journalisé dans l'audit, comme la
  publication d'un exercice.
- Alternatives écartées :
  - **Assets embarqués** : imposent une livraison par photo, alourdissent
    l'application pour tout le monde, et réservent la mise à jour du catalogue
    aux développeurs. C'est précisément ce que cet ADR remplace pour les
    illustrations d'exercices.
  - **Binaires en base** (`bytea`) : gonfle les sauvegardes et la réplication
    d'un ordre de grandeur, fait transiter chaque octet par l'API, et interdit
    tout cache HTTP en amont. PostgreSQL n'est pas un serveur de fichiers.
  - **Servir les fichiers par un endpoint de l'API** (l'API relit l'objet et le
    renvoie) : ajoute une dépendance forte au stockage sur le chemin de lecture,
    consomme de la bande passante applicative et supprime le bénéfice du cache.

## Avantages

- Le catalogue s'illustre depuis le back-office, sans développeur ni livraison.
- Les objets sont immuables : la clé de stockage porte l'identifiant du média
  (`image/<uuid>.webp`), donc `Cache-Control: immutable` sur un an est
  légitime — remplacer une photo, c'est déposer un autre média.
- Le même mécanisme accueillera les maillages 3D et les vidéos sans nouveau
  modèle : `MediaKind` existe déjà, seul le type MIME accepté change.
- La lecture ne dépend pas de l'API : si le stockage est indisponible, les
  dépôts échouent mais l'application continue de fonctionner ; inversement, une
  API arrêtée ne rend pas les images inaccessibles.

## Inconvénients

- **Une dépendance d'infrastructure de plus** à exploiter, sauvegarder et
  sécuriser (le bucket doit être lisible en anonyme mais jamais inscriptible).
- **Deux systèmes à garder cohérents** : la base et le stockage. L'ordre des
  écritures devient une décision — l'objet part avant la ligne, si bien qu'une
  coupure laisse au pire un fichier orphelin, jamais une URL morte servie aux
  applications.
- **Les images ne sont plus disponibles hors ligne** par construction, alors
  qu'un asset embarqué l'était toujours. Le cache disque du client atténue le
  problème pour les exercices déjà consultés, sans le supprimer.
- **Une URL publique est publique** : les photos du catalogue sont accessibles à
  qui connaît l'adresse, y compris pour un exercice premium. Une illustration
  n'est pas un secret ; le contenu réellement premium reste protégé par
  l'entitlement côté API (ADR 0006).
- Le développement local exige MinIO en plus de PostgreSQL et Redis.

## Conséquences

- `MediaAsset` (identifiant fourni par l'administration, clé de stockage unique,
  type MIME, taille, dimensions, empreinte SHA-256, suppression logique) et les
  colonnes `Exercise.imageId` / `Exercise.meshId` en `ON DELETE SET NULL`.
- Le dépôt est **rejouable** : l'identifiant vient de l'administration, si bien
  qu'un envoi relancé après une coupure ne crée ni second objet ni seconde
  ligne.
- La suppression est **logique** et **refusée tant qu'un exercice référence le
  média** : une photo ne disparaît pas des applications déjà installées par
  accident.
- Le rattachement d'un média invalide le cache Redis du catalogue — sans quoi
  une nouvelle photo attendrait l'expiration du cache.
- L'API expose `imageUrl` sur le résumé d'exercice et `meshUrl` sur son détail ;
  la clé de stockage, elle, ne sort jamais de l'API.
- L'indisponibilité du stockage **ne rend pas l'API non prête** : elle n'affecte
  que les dépôts d'administration. Elle est signalée par un avertissement au
  démarrage.
- Les vignettes des groupes musculaires et les éléments de charte graphique
  restent des assets embarqués : ils appartiennent au design system, pas au
  contenu.

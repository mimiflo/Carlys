# ADR 0006 — Entitlements côté serveur pour les abonnements

## Statut

Acceptée — 2026-08

## Contexte

Carlys aura des abonnements (Étape 6) : achats in-app iOS/Android
(RevenueCat envisagé) et paiement web Stripe, avec webhooks signés et
idempotents. L'anti-modèle classique consiste à tester un nom de plan en dur
dans le code (`user.plan === "premium"`) : chaque nouveau plan, essai gratuit,
offre de lancement, geste commercial ou remboursement oblige alors à modifier
toutes les conditions dispersées dans le mobile, l'admin et l'API. Le statut
d'abonnement, lui, provient de sources multiples et asynchrones (stores,
Stripe, actions admin) et change hors de tout parcours applicatif.

## Décision

L'accès aux fonctionnalités payantes repose sur des **entitlements (droits
effectifs) calculés et servis par le serveur**. Le code client et le code
serveur testent des **capacités** (« cet utilisateur a-t-il le droit
`advanced_stats` ? »), jamais un nom de plan. La correspondance
plan → entitlements vit en un seul endroit, côté API, et l'API reste l'autorité
finale sur chaque action protégée.

## Raisons

- **Découplage produit/code** : créer un plan, un essai, une promo ou un plan
  « Coach » revient à modifier la table de correspondance, pas les dizaines de
  points de contrôle.
- **Une seule source de vérité** : stores, Stripe et gestes admin convergent
  vers le même état serveur ; remboursements, expirations et périodes de grâce
  sont appliqués centralement.
- **Sécurité** : un client (mobile ou web) peut être manipulé ; seule la
  vérification serveur d'un droit protège réellement une ressource. Le client
  n'utilise les entitlements que pour l'affichage.
- **Compatibilité RevenueCat/Stripe** : les deux exposent nativement une notion
  d'entitlement/produit distincte du plan tarifaire — la décision aligne notre
  modèle sur celui des fournisseurs, webhooks idempotents signés à l'appui.
- Alternative écartée : **tests de plan en dur** — simple au premier plan,
  ingérable dès le deuxième, et impossible à corriger a posteriori sans
  repasser sur tout le code.

## Avantages

- Extensible sans refonte : plans Coach, essais, offres partenaires,
  remboursements partiels se modélisent comme des ensembles de droits datés.
- Testable : la logique « droits effectifs à l'instant T » est une fonction
  pure côté serveur, couverte par des tests unitaires.
- Auditable : l'historique des changements d'entitlements (webhook reçu, geste
  admin) trace qui a eu accès à quoi et pourquoi — utile pour le support et
  l'Étape 7 (audit).
- Cohérence multi-plateforme : mobile, web et admin lisent le même état.

## Inconvénients

- Plus de travail initial qu'un simple champ `plan` : table de correspondance,
  endpoint de lecture des droits, guards serveur, cache client.
- Le mobile offline-first (ADR 0005) doit gérer des droits **mis en cache
  localement**, avec une durée de validité : hors ligne, l'app applique le
  dernier état connu — un délai de propagation (upgrade ou révocation) est
  accepté.
- Dépendance à des webhooks externes : leur idempotence, leur signature et leur
  rejeu doivent être irréprochables, sinon l'état des droits dérive.

## Conséquences

- Règle de code, applicable dès maintenant : **aucun test de nom de plan en
  dur** (`plan === "premium"` est interdit en revue) ; toute condition d'accès
  nomme un droit.
- L'Étape 6 livrera : modèles Prisma des abonnements et entitlements, endpoint
  des droits effectifs, guards NestJS par entitlement, webhooks
  Stripe/RevenueCat signés et idempotents.
- Le client mobile met en cache les entitlements (avec les données locales
  Drift) et les rafraîchit à la synchronisation ; l'API revalide
  systématiquement côté serveur.
- Les écrans d'achat affichent des plans ; le reste de l'app ne connaît que des
  droits.

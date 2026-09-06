# Chemin d'achat Premium

Le catalogue d'offres, la page de paiement, et surtout la frontière : ce que
l'application a le droit de décider, et ce qu'elle ne décide jamais.

## Un seul principe

**L'application n'accorde jamais Premium.** Elle ouvre une page de paiement ;
l'argent est encaissé par le prestataire ; le serveur accorde le droit sur
**webhook signé**. Un écran qui déciderait du droit au retour de la page de
paiement suffirait à contourner la caisse : il suffirait de fermer l'onglet
au bon moment.

C'est pourquoi `POST /subscriptions/checkout` ne touche à aucun droit, et
pourquoi l'écran se contente de relire `/subscriptions/me` au retour.

## Les prix viennent du serveur

`GET /api/v1/subscriptions/offers` sert le catalogue. Rien n'est chiffré dans
l'application : un tarif écrit dans le mobile deviendrait faux le jour où il
change, et il faudrait publier une mise à jour sur deux magasins pour
corriger un prix.

| Champ | D'où il vient |
| ----- | ------------- |
| `amountCents`, `currency` | Configuration serveur (`SUBSCRIPTION_*`) |
| `monthlyEquivalentCents` | **Calculé** : annuel ÷ 12 |
| `savingPercent` | **Calculé** : 1 − (équivalent mensuel ÷ mensuel) |
| `isRecommended` | **Calculé** : l'annuel, s'il fait réellement économiser |
| `checkoutAvailable` | Le paiement est-il configuré côté serveur |

Ce qui se calcule ne se saisit jamais : un rabais saisi à la main survit à un
changement de prix et se met à mentir. Sans avantage réel, ni badge ni
recommandation — annoncer « 0 % offert » décrédibilise tout le reste.

## Ce que voit l'utilisateur selon l'état du serveur

| État | Écran |
| ---- | ----- |
| Paiement configuré | Les offres, et le bouton « Passer à Premium » |
| Paiement non configuré | Les offres, et une phrase qui dit que l'achat arrive |
| Catalogue en erreur | Rien de plus : la page a déjà dit ce qu'apporte Premium |

Montrer un bouton d'achat qui échouerait est pire que de ne pas en montrer.

## Le trajet, bout à bout

1. L'app engendre un **UUID hors ligne** et appelle `POST /subscriptions/checkout`.
2. Le serveur ouvre une session Stripe avec cet identifiant comme
   `Idempotency-Key` : réappuyer rend la **même** page de paiement.
   `client_reference_id` porte l'identifiant utilisateur.
3. L'app ouvre l'adresse dans le navigateur (`url_launcher`, hors application).
4. Stripe encaisse, puis appelle `POST /api/v1/webhooks/stripe` — **signé**,
   **idempotent** (journal `SubscriptionEvent`).
5. Le webhook crée l'abonnement et le droit. `/entitlements` change.
6. Stripe renvoie le navigateur vers `${PUBLIC_APP_URL}/abonnement/merci`
   (ou `/abonnement` si le paiement est abandonné) : deux pages publiques
   statiques de l'application Next.js (`apps/admin`, groupe de routes
   `(public)`) qui invitent à retourner dans l'application. Elles
   n'accordent rien : le droit vient du webhook, jamais de la page.
7. Au **retour dans l'application**, `planStatusProvider` et
   `entitlementsProvider` sont relus, puis relus une seconde fois quelques
   secondes plus tard (voir ci-dessous). S'ils n'ont pas encore changé,
   l'utilisateur voit toujours son plan réel, jamais un Premium supposé.

## Le retour dans l'application

`launchUrl` rend la main dès que le navigateur **s'ouvre**, pas quand
l'utilisateur revient. Relire le plan à ce moment-là, c'est relire l'état
d'avant l'achat : l'écran restait sur « Gratuit » jusqu'à ce qu'on le quitte
et qu'on y revienne. L'action d'achat ne relit donc **rien**.

La relecture se fait au retour au premier plan :

| Pièce | Rôle |
| ----- | ---- |
| `SubscriptionResumeListener` (widget, posé sur l'écran d'abonnement) | Un `AppLifecycleListener` dont `onResume` déclenche la relecture |
| `SubscriptionResumeRefresh` (contrôleur, provider global) | Invalide `planStatusProvider` et `entitlementsProvider` tout de suite, puis **une seule fois** après `webhookGrace` |

Pourquoi sur l'écran et non sur la coquille des onglets : le parcours de
première ouverture montre l'abonnement **hors** coquille, et c'est là aussi
que l'on paie. Pourquoi une relance différée : Stripe appelle le webhook de
son côté, et il peut arriver quelques secondes **après** que l'utilisateur
est revenu. La relance est unique, et un second retour avant qu'elle ne
parte la remplace, jamais ne la double. Le contrôleur vit avec le conteneur
de providers : fermer l'écran avant la relance ne l'annule pas, et le profil,
qui affiche le même plan, en profite.

Invalider un provider `autoDispose` compte comme un rafraîchissement pour
Riverpod : l'écran garde la valeur précédente pendant la lecture, sans
clignoter vers un état de chargement.

## Découpage

| Fichier | Rôle |
| ------- | ---- |
| `application/subscription-offers.ts` | Le barème du catalogue, fonction PURE |
| `infrastructure/stripe-checkout.client.ts` | Le SEUL fichier qui connaisse l'API de Stripe |
| `presentation/widgets/subscription_purchase_panel.dart` | Les offres et le bouton |
| `presentation/controllers/subscription_controllers.dart` | L'action d'achat, testable sans navigateur |
| `presentation/controllers/subscription_resume_refresh.dart` | La relecture au retour, et sa relance unique |
| `presentation/widgets/subscription_resume_listener.dart` | L'écoute du retour au premier plan |

L'ouverture d'URL passe par `urlOpenerProvider` : un test ne doit jamais
lancer un navigateur.

## Pas de SDK Stripe

Le dépôt vérifie déjà les signatures de webhook à la main
(`stripe-signature.util.ts`), et une seule route de l'API Stripe est appelée.
Ajouter la bibliothèque complète pour un `POST` en formulaire coûterait une
dépendance de plus sans rien simplifier.

## Ce qui reste à faire avant les magasins d'applications

Apple impose l'achat intégré (StoreKit) pour un abonnement numérique : une
page de paiement externe fait refuser la publication sur l'App Store. Le
chemin décrit ici est donc **web et Android**.

Le jour où l'on passe par les magasins, un frère de
`stripe-checkout.client.ts` apparaît (RevenueCat, qui unifie les deux
magasins) et rien d'autre ne bouge : les droits sont déjà accordés par
webhook, déjà idempotents, et `PaymentProvider` porte déjà `APP_STORE` et
`PLAY_STORE`.

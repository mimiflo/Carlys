# Notifications push

Notifications envoyées par **Firebase Cloud Messaging** (FCM), décidées
**côté serveur uniquement**. Trois événements notifient aujourd'hui, tous
communautaires :

| Événement | Destinataire | Contenu |
| --------- | ------------ | ------- |
| Nouvelle demande d'ami (ou redemande après refus) | Le destinataire de la demande | « _Nom_ souhaite devenir ton ami. » |
| Demande acceptée (bouton ou demandes croisées) | Le demandeur d'origine | « _Nom_ a accepté ta demande d'ami. » |
| Encouragement reçu | L'ami encouragé | Le message, titré « Encouragement de _Nom_ » |

Un **refus** de demande d'ami ne notifie jamais personne : refuser reste
silencieux, comme le veut la logique anti-énumération de la communauté.

## Principes

- **Jamais bloquant** : une notification est un à-côté. L'envoi (nom lu,
  jeton lu, appel FCM) est enveloppé pour ne **jamais** faire échouer le flux
  métier qui l'a déclenché — un échec est journalisé, c'est tout.
- **Dégradation propre** : sans configuration (Firebase côté app, compte de
  service côté API), tout le reste fonctionne à l'identique. Le push est un
  interrupteur, pas une dépendance.
- **Permission respectée** : sur Android 13+ et iOS la permission se demande ;
  la refuser n'enregistre rien et ne produit aucune erreur.
- **Un jeton = un compte** : le jeton FCM est unique en base ; se connecter
  avec un autre compte sur le même appareil le réaffecte (upsert). Les jetons
  que FCM déclare morts sont purgés au fil des envois.

## Côté serveur (`apps/api`)

- Modèle Prisma `DeviceToken` (jeton unique, plateforme, cascade à la
  suppression du compte) — migration `20260811210000_device_tokens`.
- Module `notifications` :
  - `POST /api/v1/notifications/device-tokens` — enregistrement idempotent ;
  - `DELETE /api/v1/notifications/device-tokens` — oubli à la déconnexion,
    idempotent et limité aux jetons de l'appelant ;
  - `NotificationsService.sendToUser()` — envoi à tous les appareils de la
    personne, purge des jetons invalides, **ne lève jamais**.
- L'envoyeur FCM (`firebase-admin`, messagerie uniquement) vit derrière le
  port `PUSH_SENDER_PORT` : les tests substituent un faux, rien ne sort sur
  le réseau.
- Configuration : `FIREBASE_SERVICE_ACCOUNT_JSON` (JSON complet du compte de
  service, console Firebase → Paramètres → Comptes de service). **Optionnel**
  — absent, l'envoi est inactif mais l'enregistrement des jetons continue :
  fournir la clé plus tard active les envois sans redéployer l'application
  mobile.

## Côté mobile (`apps/mobile`)

- Feature `lib/features/notifications/` : port `PushMessenger` (seul
  `FirebasePushMessenger` connaît les plugins Firebase), dépôt Dio des
  jetons, et `PushRegistration` — même modèle que `SyncLifecycle`, démarré à
  l'entrée dans l'application authentifiée (accueil).
- Initialisation **programmatique** : les options Firebase sont injectées au
  lancement (`--dart-define-from-file=config/firebase.json`, gabarit dans
  `config/firebase.example.json`, valeurs reprises de `google-services.json`).
  Aucun `google-services.json` ni greffon Gradle dans `android/` — qui n'est
  de toute façon pas versionné.
- Cycle : permission → jeton → `POST device-tokens` ; ré-enregistrement à
  chaque rafraîchissement de jeton FCM ; à la déconnexion, oubli côté serveur
  (pendant que l'appel est encore authentifié) puis invalidation locale.
- Sans configuration (tests, CI, démo) : no-op journalisé, aucun plugin
  touché — c'est ce que vérifient les tests de `PushRegistration`.
- `scripts/bootstrap_mobile.sh` déclare `POST_NOTIFICATIONS` dans le
  manifeste Android généré (obligatoire depuis Android 13).

## Réception

Les messages envoyés sont des messages **de notification** (titre + corps) :
en arrière-plan, le système les affiche lui-même dans la barrette — aucun
gestionnaire d'arrière-plan n'est nécessaire. L'affichage au premier plan
(bannière dans l'application) viendra avec un futur écran de préférences de
notification.

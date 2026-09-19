import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/restore/app_restore.dart';
import '../../features/academy/data/answered_lessons_store.dart';
import '../../features/academy/presentation/controllers/academy_controllers.dart';
import '../../features/community/presentation/controllers/community_controllers.dart';
import '../../features/mentor/data/mentor_prefs_store.dart';
import '../../features/mentor/presentation/controllers/mentor_controllers.dart';
import '../../features/notifications/presentation/controllers/notification_preferences.dart';
import '../../features/onboarding/data/first_run_store.dart';
import '../../features/progress/presentation/controllers/progress_controllers.dart';
import '../../features/progression/data/reward_ledger.dart';
import '../../features/progression/presentation/controllers/reward_controllers.dart';
import '../../features/subscription/presentation/controllers/subscription_controllers.dart';
import '../logging/app_logger.dart';
import '../synchronization/sync_lifecycle.dart';
import 'app_database.dart';
import 'local_account_owner.dart';

/// Efface tout ce que l'appareil garde POUR UN COMPTE : le compte suivant
/// sur le même appareil repart de zéro et déclenche son propre rapatriement.
///
/// Sans elle, le compte suivant voyait l'historique, les modèles et
/// l'hydratation du précédent, et la file de synchronisation partait avec
/// son jeton — les séances de l'un atterrissaient chez l'autre.
///
/// Trois appelants, et seulement trois : la déconnexion volontaire
/// (`AuthController.logout`, immédiate), la connexion d'un compte DIFFÉRENT
/// (`LocalAccountSwitch`, différée jusque-là) et la suppression du compte.
/// Pas l'expiration de session : elle frappe le même utilisateur, et purger
/// à ce moment-là détruisait son propre travail hors ligne.
abstract interface class LocalAccountPurge {
  Future<void> run();
}

/// Purge réelle : base Drift entière, préférences propriétaires du compte,
/// puis renouvellement des providers qui tiennent l'état du compte.
class DriftLocalAccountPurge implements LocalAccountPurge {
  DriftLocalAccountPurge(this._ref);

  static const _logger = AppLogger('LocalAccountPurge');

  /// Préférences locales qui appartiennent au COMPTE, pas à l'appareil :
  /// le journal des récompenses, les questions d'Academy déjà abordées, et
  /// les réponses d'onboarding restées en attente d'envoi.
  ///
  /// Ces réponses décrivent une PERSONNE (poids, taille, âge, objectif,
  /// profil Carlys), pas un appareil : `FirstRunController` les rejoue à
  /// CHAQUE session authentifiée et les conserve tant que l'envoi échoue.
  /// Les laisser, c'était écrire le profil métabolique de celui qui part sur
  /// le compte de celui qui arrive.
  ///
  /// Le marqueur de propriétaire part aussi : après la purge, l'appareil ne
  /// porte plus les données de personne.
  ///
  /// Le thème et l'ÉTAPE atteinte du parcours de première ouverture restent :
  /// eux décrivent bien l'appareil et son premier lancement.
  static const List<String> accountOwnedPreferenceKeys = [
    RewardLedger.key,
    AnsweredLessonsStore.key,
    FirstRunStore.answersKey,
    // Les célébrations que le Mentor a DITES : les identifiants de
    // récompense sont ceux du catalogue, identiques pour tous — laisser la
    // liste, c'était voler au compte suivant la fête de « maitrise-5 »
    // parce que le précédent l'avait déjà entendue. La voix, la visite et
    // les interventions, elles, décrivent l'appareil et restent.
    MentorPrefsStore.celebrationsDitesKey,
    LocalAccountOwner.key,
  ];

  /// Providers qui gardent en MÉMOIRE des données du compte : sans eux,
  /// l'effacement du disque est annulé par le cache.
  ///
  /// Le code ami de celui qui part serait montré et partagé par le suivant ;
  /// les questions d'Academy abordées et les récompenses obtenues seraient
  /// les siennes à l'écran — et le journal des récompenses, une fois relu
  /// depuis ce cache, se réécrirait dans les préférences du nouveau compte.
  ///
  /// `personalRecordsProvider` est ici MALGRÉ son `autoDispose`, et c'est le
  /// piège de cette liste : deux Provider permanents le regardent
  /// (`rewardFactsProvider` et `showcaseRewardsProvider`), et l'accueil monte
  /// le second dès le lancement. Un auditeur permanent ne relâche jamais,
  /// donc l'élément auto-disposé n'est JAMAIS détruit. Sur un téléphone
  /// partagé, le compte suivant voyait les records du précédent. La leçon
  /// générale : « auto-disposé » ne dispense pas de cette liste, c'est
  /// l'absence d'auditeur permanent qui en dispense.
  ///
  /// Cette liste est posée à côté de [accountOwnedPreferenceKeys] pour que
  /// l'ajout d'un futur cache de compte soit un geste évident.
  static final List<ProviderOrFamily> accountOwnedProviders = [
    myFriendCodeProvider,
    answeredLessonsProvider,
    earnedRewardsProvider,
    personalRecordsProvider,
    // Ce que la personne accepte de recevoir la décrit, ELLE, pas l'appareil :
    // sans cette ligne, le compte suivant ouvrait les réglages et y lisait les
    // choix du précédent.
    notificationPreferencesProvider,
    // Le cache des célébrations dites suit sa préférence, effacée ci-dessus.
    mentorCelebrationsDitesProvider,
    // LA CLÉ D'IDEMPOTENCE DE PAIEMENT, retenue par offre pour qu'un double
    // appui rouvre la MÊME page de paiement. Elle est nominative sans le
    // dire : chez le prestataire, elle désigne la session créée pour le
    // compte d'avant. Le compte suivant qui achetait la même offre sur cet
    // appareil rejouait donc cette clé et tombait sur la page de paiement
    // de quelqu'un d'autre. Le provider est permanent : seule cette ligne
    // lui rend une carte vierge.
    subscriptionActionsProvider,
  ];

  final Ref _ref;

  @override
  Future<void> run() async {
    // 1. Plus aucun déclencheur : ni drainage ni rapatriement ne doit
    //    démarrer sur la base qu'on s'apprête à vider. Le rapatriement EN
    //    VOL est annulé et ATTENDU — invalider ne tue pas un futur déjà
    //    lancé, et une de ses écritures qui aboutissait après le vidage
    //    réinjectait les séances de l'ancien compte dans le fichier SQLite
    //    que le compte suivant rouvre (le marqueur de propriétaire effacé,
    //    rien ne les purgeait plus jamais).
    _ref.invalidate(syncLifecycleProvider);
    await _ref.read(appRestoreProvider).cancelAndWait();
    _ref.invalidate(appRestoreProvider);

    // 2. La base, d'un bloc, dans une transaction.
    await _ref.read(appDatabaseProvider).wipeAll();

    // 3. Les préférences du compte.
    final preferences = await SharedPreferences.getInstance();
    for (final key in accountOwnedPreferenceKeys) {
      await preferences.remove(key);
    }

    // 4. Une base neuve pour la suite, et les caches mémoire du compte
    //    renouvelés APRÈS l'effacement des préférences (les relire avant
    //    aurait remis en mémoire ce qu'on vient d'effacer) : tout ce qui en
    //    dépend (moteur, dépôts, flux des écrans) se reconstruit dessus, et
    //    le prochain compte déclenchera son rapatriement comme un premier
    //    démarrage.
    _ref.invalidate(appDatabaseProvider);
    for (final provider in accountOwnedProviders) {
      _ref.invalidate(provider);
    }
    _logger.info('État local du compte purgé');
  }
}

final localAccountPurgeProvider = Provider<LocalAccountPurge>(
  DriftLocalAccountPurge.new,
);

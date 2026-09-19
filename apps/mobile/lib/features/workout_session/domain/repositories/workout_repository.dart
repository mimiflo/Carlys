import '../entities/workout.dart';

/// Contrat du domaine séance.
///
/// Toutes les écritures vont D'ABORD dans la base locale (jamais de perte),
/// puis sont poussées vers le serveur via la file de synchronisation.
abstract interface class WorkoutRepository {
  /// La séance en cours (au plus une), avec ses séries, en temps réel.
  Stream<WorkoutWithSets?> watchActiveWorkout();

  /// Historique local (séances terminées ou abandonnées), plus récentes d'abord.
  Stream<List<WorkoutHistoryEntry>> watchHistory();

  Future<WorkoutWithSets?> workoutDetail(String sessionId);

  /// L'identifiant de la séance en cours, lu dans la BASE, ou `null`.
  ///
  /// Distinct de [watchActiveWorkout] et de son provider, qui sont un CACHE :
  /// ce flux Drift se termine sur erreur, et le provider qui le porte n'est
  /// pas `autoDispose` — un échec de lecture y reste donc collant pour toute
  /// la vie de l'application, seul l'écran de séance offrant un
  /// « Réessayer ». Les écrans qui décident « reprendre la séance ouverte,
  /// sinon en ouvrir une » lisaient ce cache : sur un cache en échec ils
  /// voyaient `null` alors qu'une séance existait, et [startWorkout] levait
  /// un `StateError` que personne n'attrapait — la série saisie disparaissait
  /// sans un mot. Cette lecture-ci va à la source.
  Future<String?> activeWorkoutId();

  /// Démarre une séance ; échoue si une séance est déjà en cours.
  ///
  /// [templateId] / [templateName] tracent la provenance quand la séance est
  /// lancée depuis un modèle. Le serveur ne refuse **jamais** une séance à
  /// cause d'un modèle inconnu : il ignore alors l'identifiant et conserve le
  /// nom transmis par le client.
  Future<String> startWorkout({
    String? name,
    String? templateId,
    String? templateName,
  });

  /// Enregistre une série réalisée et renvoie son identifiant (UUID appareil).
  ///
  /// L'identifiant est nécessaire pour rattacher la série à l'item de plan
  /// qu'elle honore (cf. `workout_template`).
  Future<String> addSet(AddSetInput input);

  /// Corrige une série DÉJÀ enregistrée : le fait réalisé, rien d'autre.
  ///
  /// La cible affichée au moment de la validation (`planned*`) n'est jamais
  /// réécrivable, côté serveur comme ici : c'est un fait historique.
  ///
  /// Passe par `PATCH /workout-sets/{id}` et NON par le réenregistrement de
  /// la série : l'ajout est un upsert idempotent par identifiant, donc rejoué
  /// avec le même UUID il rend la série existante sans la modifier.
  Future<void> updateSet(String setId, {int? reps, double? weightKg});

  Future<void> deleteSet(String setId);

  Future<void> completeWorkout(String sessionId);

  Future<void> abandonWorkout(String sessionId);

  /// Tranche un conflit de clôture ([LocalSyncState.conflict]) : rapatrie la
  /// version du serveur, ou rejoue la version locale. Jette l'`AppException`
  /// de la lecture distante quand le serveur est inaccessible ; rien n'est
  /// alors modifié.
  Future<void> resolveCloseConflict(
    String sessionId,
    WorkoutConflictResolution resolution,
  );

  /// Redonne sa chance, sur DEMANDE de l'utilisateur, à ce que la
  /// synchronisation a mis de côté, puis relance un envoi.
  ///
  /// Une opération mise de côté (trop d'erreurs serveur d'affilée) reste
  /// visible en échec, mais son seul rejeu automatique est l'ouverture
  /// suivante de l'application : sans ce geste, l'utilisateur devrait tuer et
  /// relancer l'application pour retenter dans la même session.
  Future<void> retryFailedSync();

  /// Rapatrie les séances du serveur dans la base locale, avec leurs séries
  /// **et leur plan**.
  ///
  /// Utile après une réinstallation ou un changement d'appareil : c'est ce qui
  /// permet de reprendre sur un second téléphone une séance commencée sur un
  /// premier, cibles comprises. Ne touche jamais une séance dont des
  /// modifications locales n'ont pas encore été acquittées : l'appareil ne
  /// perd jamais sa propre saisie.
  ///
  /// [shouldContinue], consulté entre deux séances, permet d'ARRÊTER un
  /// rapatriement en vol : la purge de compte s'en sert pour qu'aucune
  /// écriture ne retombe dans la base après son vidage.
  Future<void> restoreSessions({bool Function()? shouldContinue});
}

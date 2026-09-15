import '../../../workout_session/domain/entities/workout.dart';
import '../entities/session_plan.dart';
import '../entities/workout_template.dart';

/// Contrat du domaine « modèle de séance ».
///
/// Mêmes garanties que le domaine séance : **toute écriture va d'abord dans
/// Drift**, dans la même transaction que la mise en file de synchronisation ;
/// aucun appel réseau n'est jamais fait avant l'écriture locale, et toutes les
/// lectures viennent du local (donc fonctionnent hors ligne).
abstract interface class WorkoutTemplateRepository {
  /// Modèles de l'utilisateur, plus récemment modifiés d'abord, en temps réel.
  /// Les modèles supprimés (tombstone local) en sont exclus.
  Stream<List<WorkoutTemplateInfo>> watchTemplates();

  /// Contenu complet d'un modèle, ou `null` s'il n'existe pas / est supprimé.
  Future<WorkoutTemplateDetail?> templateDetail(String templateId);

  /// Crée ou remplace **intégralement** un modèle et renvoie son identifiant.
  ///
  /// Le contenu local (lignes et séries) est physiquement réécrit, en miroir
  /// exact du `PUT` serveur ; une seule opération `template.save` est enfilée,
  /// quel que soit le nombre d'exercices.
  ///
  /// Lève [InvalidTemplateException] si la saisie sort des bornes partagées
  /// avec l'API — le contrôle a lieu **avant** toute écriture.
  Future<String> saveTemplate(SaveTemplateInput input);

  /// Suppression logique : le modèle disparaît des listes immédiatement, une
  /// opération `template.delete` (rejouable) part vers le serveur.
  ///
  /// Les séances déjà réalisées ne bougent pas : elles gardent leur
  /// `templateName` dénormalisé et les cibles de leurs séries.
  Future<void> deleteTemplate(String templateId);

  /// **Lance le modèle** : crée la séance (UUID appareil) ET matérialise le
  /// plan, dans UNE SEULE transaction locale. Renvoie l'id de séance.
  ///
  /// N'appelle jamais l'API : lancer un modèle fonctionne intégralement hors
  /// ligne. Lève un [StateError] si une séance est déjà en cours, ou si le
  /// modèle est introuvable.
  Future<String> startFromTemplate(String templateId);

  /// Plan d'une séance, en temps réel. `null` pour une séance libre (sans
  /// modèle) : l'écran de séance garde alors exactement son comportement
  /// actuel.
  Stream<SessionPlan?> watchSessionPlan(String sessionId);

  /// Plan d'une séance, lecture ponctuelle.
  Future<SessionPlan?> sessionPlan(String sessionId);

  /// Item de plan que la prochaine série validée sur cet exercice honorerait,
  /// `null` s'il n'y en a aucun (série supplémentaire, exercice hors
  /// programme, séance libre).
  ///
  /// Règle d'appariement, déterministe et sans heuristique : le **premier item
  /// de l'exercice concerné qui n'est ni fait ni sauté**.
  Future<SessionPlanItem?> nextPlanItemFor({
    required String sessionId,
    required String exerciseName,
    String? exerciseId,
  });

  /// Marque l'item honoré par la série [setId]. Idempotent.
  Future<void> fulfillPlanItem({
    required String planItemId,
    required String setId,
  });

  /// Écrit la série ET le pointage de l'item de plan en UNE SEULE écriture,
  /// puis rend l'identifiant de la série.
  ///
  /// Les deux gestes étaient deux transactions distinctes : une application
  /// tuée entre elles — mise à mort par le système pendant le repos entre
  /// deux séries, ou balayage de l'application — laissait la série
  /// enregistrée et la case du plan VIDE. Le plan réclamait alors une série
  /// déjà faite, et la refaire créait un doublon. Le serveur, lui, n'était
  /// jamais perdu (l'appariement voyage dans la charge utile de la série), et
  /// un rapatriement finissait par réparer ; mais entre-temps l'écran mentait.
  Future<String> recordSetFulfillingPlan({
    required AddSetInput input,
    required String planItemId,
  });

  /// Passe une série prévue. Rien n'est envoyé au serveur.
  Future<void> skipPlanItem(String planItemId);

  /// Passe toutes les séries restantes d'un exercice du programme.
  Future<void> skipPlanExercise({
    required String sessionId,
    required int exercisePosition,
  });

  /// Supprime le plan local d'une séance (à la clôture, après rétention).
  Future<void> purgeSessionPlan(String sessionId);

  /// Rapatrie les modèles du serveur dans la base locale.
  ///
  /// Utile après une réinstallation ou un changement d'appareil. Ne touche
  /// jamais aux modèles dont des modifications locales n'ont pas encore été
  /// acquittées : l'appareil ne perd jamais sa propre saisie.
  Future<void> refreshTemplates();
}

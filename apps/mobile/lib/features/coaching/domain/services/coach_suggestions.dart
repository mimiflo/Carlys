/// Amorces de conversation, **calculées depuis l'état réel**.
///
/// Un champ vide invite des questions que le domaine ne sait pas honorer :
/// « combien de protéines ai-je mangé hier ? » n'a pas de réponse, l'app ne
/// tient pas de journal alimentaire. Ces puces orientent vers ce que le coach
/// sait vraiment faire, et elles ne sont donc **jamais codées en dur** : sans
/// données, il n'en reste qu'une, générique et honnête.
library;

import '../../../../core/utilities/civil_days.dart';
import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../entities/coach.dart';

/// Ce que l'application sait de l'utilisateur au moment d'ouvrir le coach.
///
/// Volontairement réduit à des valeurs simples plutôt qu'aux entités des
/// autres fonctionnalités : la règle est testable seule, et `coaching` ne
/// dépend pas de la forme interne de `progress` ou `workout_template`.
class CoachContext {
  const CoachContext({
    this.carlysProfile,
    this.templateName,
    this.recordExerciseName,
    this.recordAgeDays,
    this.weightTrendKg,
    this.hasHistory = false,
  });

  /// Identité Carlys choisie — une préférence déclarée, donc une donnée
  /// aussi réelle que les autres. `null` tant qu'elle ne l'est pas.
  final CarlysProfile? carlysProfile;

  /// Nom d'un modèle de séance disponible, s'il y en a un.
  final String? templateName;

  /// Exercice du record le plus récent.
  final String? recordExerciseName;

  /// Ancienneté de ce record, en jours.
  final int? recordAgeDays;

  /// Variation de poids sur la période observée, en kilos. `null` si moins de
  /// deux mesures : une seule mesure ne fait pas une tendance.
  final double? weightTrendKg;

  /// L'utilisateur a au moins une séance terminée.
  final bool hasHistory;
}

/// Au-delà, un record n'est plus « récent » et la question devient un
/// reproche plutôt qu'une amorce.
const int _freshRecordDays = 21;

/// En deçà, la variation de poids est du bruit de balance, pas une tendance.
const double _weightNoiseKg = 0.4;

/// Ce que propose une amorce : l'écran en tire son icône (une horloge pour
/// adapter une séance, une ampoule pour comprendre…), le domaine n'en sait
/// rien de plus.
enum CoachSuggestionKind { adapt, understand, progress, weight, start }

/// Une amorce : sa phrase, et ce qu'elle propose.
class CoachSuggestion {
  const CoachSuggestion(this.text, this.kind);

  final String text;
  final CoachSuggestionKind kind;
}

/// Trois puces au plus : au-delà, la bande défile et la dernière ne se lit
/// plus. Elles sortent dans l'ordre d'utilité, la plus actionnable d'abord.
const int maxCoachSuggestions = 3;

List<CoachSuggestion> coachSuggestions(CoachContext context) {
  final suggestions = <CoachSuggestion>[];

  // La plus actionnable : elle finit sur une séance qu'on peut lancer.
  if (context.templateName != null) {
    suggestions.add(
      CoachSuggestion(
        'Adapte « ${context.templateName} » à 30 minutes',
        CoachSuggestionKind.adapt,
      ),
    );
  } else if (context.hasHistory) {
    suggestions.add(
      const CoachSuggestion(
        'Propose-moi une séance courte',
        CoachSuggestionKind.adapt,
      ),
    );
  }

  // L'identité choisie oriente l'angle : c'est la promesse des profils.
  final profile = context.carlysProfile;
  if (profile != null) {
    suggestions.add(
      CoachSuggestion(
        switch (profile) {
          CarlysProfile.constructeur =>
            'Explique-moi les bases d’une séance efficace',
          CarlysProfile.challenger =>
            'Rends ma prochaine séance plus exigeante',
          CarlysProfile.athlete =>
            'Aide-moi à tenir mon objectif cette semaine',
          CarlysProfile.stratege => 'Explique-moi le pourquoi de mes séances',
        },
        switch (profile) {
          // Pousser, tenir : une progression ; apprendre : une explication.
          CarlysProfile.challenger ||
          CarlysProfile.athlete => CoachSuggestionKind.progress,
          CarlysProfile.constructeur ||
          CarlysProfile.stratege => CoachSuggestionKind.understand,
        },
      ),
    );
  }

  final record = context.recordExerciseName;
  final age = context.recordAgeDays;
  if (record != null && age != null) {
    suggestions.add(
      CoachSuggestion(
        age <= _freshRecordDays
            ? 'Comment continuer sur $record ?'
            : 'Je stagne sur $record, que faire ?',
        CoachSuggestionKind.progress,
      ),
    );
  }

  final trend = context.weightTrendKg;
  if (trend != null && trend.abs() >= _weightNoiseKg) {
    suggestions.add(
      CoachSuggestion(
        trend > 0
            ? 'Mon poids monte, dois-je changer quelque chose ?'
            : 'Mon poids baisse, est-ce que je perds du muscle ?',
        CoachSuggestionKind.weight,
      ),
    );
  }

  // Aucune donnée : une seule puce, qui n'invente rien sur l'utilisateur.
  if (suggestions.isEmpty) {
    return const [
      CoachSuggestion('Par où je commence ?', CoachSuggestionKind.start),
    ];
  }

  return suggestions.take(maxCoachSuggestions).toList();
}

/// La personne a-t-elle déjà écrit au coach AUJOURD'HUI (jour local) ?
///
/// Les amorces servent à lancer la conversation du jour : une fois lancée,
/// elles s'effacent jusqu'au lendemain. Un message sans date ne compte pas :
/// on n'invente pas de jour.
bool coachWroteToday(Iterable<CoachMessage> messages, DateTime now) =>
    messages.any((message) {
      final at = message.createdAt;
      return message.role == CoachRole.user &&
          at != null &&
          joursCivilsEntre(at, now) == 0;
    });

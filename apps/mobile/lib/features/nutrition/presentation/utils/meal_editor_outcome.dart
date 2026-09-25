/// Les mots que l'écran de repas et son contrôleur échangent : QUEL repas
/// on édite, et ce qu'il est advenu d'un geste. Sortis du contrôleur pour
/// que celui-ci ne porte que sa conduite.
library;

/// Quel repas l'écran édite : [mealId] nul pour un repas NEUF, daté du jour
/// [day] (celui qu'affiche le journal ; aujourd'hui s'il est nul).
typedef MealEditorKey = ({String? mealId, DateTime? day});

/// Ce qu'a donné un enregistrement ou une suppression, et l'erreur quand
/// le serveur ou le réseau a manqué (pour dire « hors connexion » plutôt
/// qu'« échec »).
typedef MealEditorResult = ({MealEditorOutcome outcome, Object? error});

/// L'issue d'un enregistrement ou d'une suppression.
enum MealEditorOutcome {
  /// Écrit sur le serveur : l'écran se referme.
  done,

  /// Le repas est écrit, mais sa PHOTO NEUVE n'a pas pu être envoyée.
  /// L'écran reste ouvert sur le repas enregistré, la photo toujours en
  /// attente : un nouvel appui la renvoie, rien n'est perdu.
  photoFailed,

  /// Le repas est écrit, mais sa photo n'a pas pu être RETIRÉE : elle est
  /// toujours sur le serveur. Le retrait reste demandé ; un nouvel appui le
  /// retente. (Dire « la photo n'est pas partie » serait l'inverse du vrai.)
  photoRemovalFailed,

  /// Une case est fautive : les erreurs s'affichent sous les cases.
  invalid,

  /// Le repas est daté du futur : le serveur le refuserait.
  future,

  /// Le serveur ou le réseau a manqué : rien n'est perdu, l'écran reste.
  failed,

  /// Un envoi est déjà en cours : rien n'est fait.
  busy,
}

/// L'instant proposé à un repas neuf, en heure locale.
///
/// Un repas ajouté depuis le jour affiché par le journal en hérite :
/// consulter mardi puis ajouter, c'est ajouter À MARDI. Aujourd'hui (ou sans
/// jour), l'heure qu'il est ; un jour passé, midi — l'heure la plus
/// plausible d'un repas qu'on rattrape, et jamais dans le futur.
DateTime initialMealInstant(DateTime? day, DateTime now) {
  if (day == null ||
      (day.year == now.year && day.month == now.month && day.day == now.day)) {
    return now;
  }
  return DateTime(day.year, day.month, day.day, 12);
}

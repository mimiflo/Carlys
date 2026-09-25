/// Le MOMENT de la journée d'un repas : petit-déjeuner, déjeuner, dîner,
/// collation.
///
/// C'est une DONNÉE enregistrée par le serveur, pas une déduction de
/// l'heure : un dîner pris à 23 h 40 reste un dîner, une collation à midi
/// reste une collation. Les repas notés avant son arrivée n'en ont pas
/// (`null`) : l'écran en PROPOSE alors un d'après l'heure ([suggestFor]),
/// qui ne s'écrit qu'à l'enregistrement suivant.
enum MealMoment {
  breakfast('BREAKFAST', 'Petit-déjeuner'),
  lunch('LUNCH', 'Déjeuner'),
  dinner('DINNER', 'Dîner'),
  snack('SNACK', 'Collation');

  const MealMoment(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// `null` pour une valeur absente OU inconnue : un serveur plus récent
  /// pourrait servir un moment que cette version ignore, et l'écran le
  /// proposera d'après l'heure plutôt que d'en afficher un faux.
  static MealMoment? fromApi(Object? value) {
    for (final moment in MealMoment.values) {
      if (moment.apiValue == value) {
        return moment;
      }
    }
    return null;
  }

  /// Le moment PROPOSÉ pour un repas pris à [local] (heure de l'appareil).
  ///
  /// Cinq plages, bornes basses incluses :
  ///  - avant 10 h 30 : petit-déjeuner (le repas de 3 h du matin d'un
  ///    travail de nuit compris : c'est le premier de sa journée) ;
  ///  - de 10 h 30 à 15 h : déjeuner ;
  ///  - de 15 h à 18 h : collation, le goûter ;
  ///  - de 18 h à 22 h 30 : dîner ;
  ///  - après 22 h 30 : collation, l'en-cas du soir.
  ///
  /// Une PROPOSITION : la personne la change d'un geste, et c'est son choix
  /// qui s'enregistre.
  static MealMoment suggestFor(DateTime local) {
    final minutes = local.hour * 60 + local.minute;
    if (minutes < _breakfastEnds) {
      return MealMoment.breakfast;
    }
    if (minutes < _lunchEnds) {
      return MealMoment.lunch;
    }
    if (minutes < _snackEnds) {
      return MealMoment.snack;
    }
    if (minutes < _dinnerEnds) {
      return MealMoment.dinner;
    }
    return MealMoment.snack;
  }

  static const int _breakfastEnds = 10 * 60 + 30;
  static const int _lunchEnds = 15 * 60;
  static const int _snackEnds = 18 * 60;
  static const int _dinnerEnds = 22 * 60 + 30;
}

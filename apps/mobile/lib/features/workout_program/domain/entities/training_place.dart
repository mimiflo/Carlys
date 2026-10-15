/// Où l'on s'entraîne : la question GLOBALE du coach sur le matériel
/// (« salle de sport », pas « barre EZ ou poulie ? »). Chaque lieu se
/// traduit en une liste de matériel du catalogue, celle qu'écrit le profil
/// d'entraînement et que lisent le coach et la génération de programme.
///
/// Le détail, accessoire par accessoire, reste réglable dans « Préparer
/// mon programme ».
enum TrainingPlace {
  /// Tout le catalogue : machines, poulies, barres, haltères…
  gym(
    'Salle de sport',
    'Machines, poulies, barres, haltères : tout le matériel d’une salle.',
    null,
  ),
  home(
    'À la maison',
    'Haltères, kettlebell, élastiques, banc, barre de traction, tapis.',
    {
      'poids-du-corps',
      'halteres',
      'kettlebell',
      'elastique',
      'banc',
      'barre-de-traction',
      'tapis',
    },
  ),
  bodyweight(
    'Sans matériel',
    'Le poids du corps, et un tapis si tu en as un.',
    {'poids-du-corps', 'tapis'},
  );

  const TrainingPlace(this.label, this.description, this._kit);

  final String label;
  final String description;

  /// `null` : tout le catalogue.
  final Set<String>? _kit;

  /// Le matériel de ce lieu, parmi ce que le [catalog] connaît : un slug
  /// absent du catalogue n'est jamais écrit au profil.
  List<String> kitIn(Iterable<String> catalog) => [
    for (final slug in catalog)
      if (_kit == null || _kit.contains(slug)) slug,
  ];

  /// Le lieu dont le matériel est EXACTEMENT [owned] — `null` pour un
  /// matériel réglé au détail, ou pas encore choisi. Deux lieux de même
  /// liste (petit catalogue) : le premier de [values] l'emporte.
  ///
  /// ponytail: « Salle de sport » = tout le catalogue AU MOMENT du choix ; un
  /// matériel ajouté plus tard au catalogue la fait lire « réglé au détail »
  /// (la personne re-touche « Salle de sport »). Stocker le lieu côté serveur
  /// si le catalogue se met à bouger souvent.
  static TrainingPlace? matching(Set<String> owned, Iterable<String> catalog) {
    if (owned.isEmpty) return null;
    return values.where((place) {
      final kit = place.kitIn(catalog).toSet();
      return kit.length == owned.length && kit.containsAll(owned);
    }).firstOrNull;
  }
}

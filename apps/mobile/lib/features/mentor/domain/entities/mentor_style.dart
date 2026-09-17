/// Les 4 styles de voix du Mentor Carlys : COMMENT il te parle.
///
/// Un axe indépendant du profil Carlys : le profil décrit qui tu es et ce
/// qu'il faut privilégier, le style décrit la voix qui te le dit. Les deux
/// se composent côté serveur (4 briefings + 4, jamais 16 croisements).
/// Le choix vit sur le profil serveur (`PATCH /users/me`), nul tant qu'il
/// n'a pas été fait — jamais une voix par défaut.
enum MentorStyle {
  bienveillant(
    'BIENVEILLANT',
    'Bienveillant',
    'Commence par ce qui va, transforme chaque critique en prochain pas. '
        'La chaleur d’abord, sans rien cacher.',
  ),
  exigeant(
    'EXIGEANT',
    'Exigeant',
    'Va droit au fait, nomme ce qui ne va pas, ne félicite que le mérité. '
        'Chaque exigence vient avec le geste pour y répondre.',
  ),
  athlete(
    'ATHLETE',
    'Athlète',
    'Parle comme un partenaire d’entraînement : phrases courtes, vocabulaire '
        'du terrain, tout ramené à la séance.',
  ),
  philosophe(
    'PHILOSOPHE',
    'Philosophe',
    'Prend de la hauteur : relie l’effort du jour à ce qu’il construit sur '
        'des mois, une idée forte à la fois.',
  );

  const MentorStyle(this.wire, this.label, this.description);

  /// Valeur échangée avec l'API.
  final String wire;

  final String label;

  /// Ce que la voix CHANGE, dit à la personne qui choisit.
  final String description;

  /// Null pour une valeur absente OU inconnue : un serveur plus récent qui
  /// ajouterait un style ne doit pas faire planter les anciens clients.
  static MentorStyle? fromWire(String? wire) {
    for (final style in values) {
      if (style.wire == wire) {
        return style;
      }
    }
    return null;
  }
}

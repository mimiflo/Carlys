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
    'Encourage et transforme chaque difficulté en prochain pas.',
  ),
  exigeant(
    'EXIGEANT',
    'Exigeant',
    'Direct, précis, avec une action concrète pour avancer.',
  ),
  athlete(
    'ATHLETE',
    'Athlète',
    'Un partenaire d’entraînement, tourné vers la séance.',
  ),
  philosophe(
    'PHILOSOPHE',
    'Philosophe',
    'Relie l’effort du jour à ce qu’il construit sur la durée.',
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

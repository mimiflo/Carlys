/// PROFIL DE PROGRESSION : cinq axes, des points, un titre.
///
/// ## Le score est DÉRIVÉ, jamais accumulé
///
/// Aucun compteur n'est incrémenté quelque part et conservé. Le profil se
/// recalcule à chaque lecture, à partir de faits que l'application possède
/// déjà : les séances réellement terminées, les charges réellement
/// soulevées, les leçons réellement répondues.
///
/// Ce choix règle d'un coup trois problèmes qu'un compteur aurait posés :
/// il ne peut pas dériver de la réalité, il ne peut pas se compter deux fois
/// si une synchronisation rejoue une opération, et il se reconstruit seul sur
/// un nouvel appareil. Le prix est assumé : effacer une séance retire ses
/// points, ce qui est la vérité.
///
/// ## Ce que la marque interdit ici
///
/// Carlys est EXIGEANTE mais BIENVEILLANTE. Un profil de progression est
/// exactement l'endroit où cette promesse se trahit le plus facilement, donc
/// trois règles s'appliquent :
///
/// - **aucun axe ne punit une absence.** Les points ne se perdent pas parce
///   qu'on s'est arrêté : ils se recalculent sur une fenêtre récente, et une
///   reprise les fait remonter tout de suite ;
/// - **aucun axe n'invente.** Sans fait, l'axe le DIT ([ProgressionAxis.known]
///   à `false`) au lieu d'afficher un zéro qui ressemblerait à un échec ;
/// - **chaque axe explique son pourquoi** ([ProgressionAxis.reason]), parce
///   qu'un score qu'on ne comprend pas n'apprend rien.
library;

import '../../../core/brand/carlys_value.dart';

export '../../../core/brand/carlys_value.dart' show CarlysValue;

/// Points maximum d'un axe. Cinq axes, donc [maxTotal] au total.
const int maxAxisPoints = 200;

/// Points maximum du profil.
const int maxTotal = maxAxisPoints * 5;

/// Titres de progression, du premier au dernier.
///
/// Ils racontent un métier qui s'apprend, pas un niveau qui se farme : on
/// commence apprenti, on finit icône. Le seuil est le total à ATTEINDRE.
enum CarlysTitle {
  apprenti('Apprenti', 0),
  architecte('Architecte', 200),
  artisan('Artisan', 420),
  maitre('Maître', 650),
  icone('Icône', 860);

  const CarlysTitle(this.label, this.threshold);

  final String label;
  final int threshold;

  /// Titre correspondant à un total de points.
  static CarlysTitle forPoints(int points) {
    var reached = CarlysTitle.apprenti;
    for (final title in CarlysTitle.values) {
      if (points >= title.threshold) {
        reached = title;
      }
    }
    return reached;
  }

  /// Titre suivant, ou `null` pour le dernier.
  CarlysTitle? get next {
    final index = CarlysTitle.values.indexOf(this) + 1;
    return index < CarlysTitle.values.length ? CarlysTitle.values[index] : null;
  }

  /// Le rang du titre en chiffres romains, tel qu'il est frappé sur son
  /// sceau. Cinq paliers : une table suffit, un convertisseur général serait
  /// du code mort.
  String get roman => const ['I', 'II', 'III', 'IV', 'V'][index];
}

/// Un axe évalué : sa valeur, ses points, et la phrase qui l'explique.
class ProgressionAxis {
  const ProgressionAxis({
    required this.value,
    required this.ratio,
    required this.points,
    required this.reason,
    this.known = true,
  });

  /// Axe sans fait disponible : l'application le dit au lieu de l'inventer.
  const ProgressionAxis.unknown(this.value, this.reason)
    : ratio = 0,
      points = 0,
      known = false;

  final CarlysValue value;

  /// Remplissage de l'axe, de 0 à 1.
  final double ratio;

  /// Points, de 0 à [maxAxisPoints].
  final int points;

  /// Pourquoi cette valeur-là, en une phrase adossée à un fait.
  final String reason;

  /// `false` quand aucun fait n'est encore disponible.
  final bool known;
}

/// Le profil complet.
class ProgressionProfile {
  const ProgressionProfile({required this.axes});

  final List<ProgressionAxis> axes;

  int get points => axes.fold(0, (sum, axis) => sum + axis.points);

  CarlysTitle get title => CarlysTitle.forPoints(points);

  /// Points restants avant le titre suivant, ou `null` au dernier titre.
  int? get pointsToNextTitle {
    final next = title.next;
    return next == null ? null : next.threshold - points;
  }

  /// Part du CHEMIN ENTIER parcourue, de 0 à 1.
  ///
  /// C'est elle que porte la jauge de la carte de titre, et non l'avancement
  /// vers le palier suivant : une jauge qui repartirait de zéro à chaque
  /// palier effacerait tout ce qui a été fait avant lui. Ici, la barre ne
  /// recule jamais d'un palier à l'autre — elle raconte l'histoire complète.
  double get totalProgress => (points / maxTotal).clamp(0.0, 1.0);

  /// Part du chemin parcouru vers le titre suivant, de 0 à 1.
  ///
  /// Au dernier titre, la barre est pleine : il n'y a plus de suite à
  /// montrer, et une barre vide y serait un contresens.
  double get progressToNextTitle {
    final next = title.next;
    if (next == null) {
      return 1;
    }
    final span = next.threshold - title.threshold;
    if (span <= 0) {
      return 1;
    }
    return ((points - title.threshold) / span).clamp(0.0, 1.0);
  }

  /// Les axes encore sans fait : l'écran les regroupe pour dire quoi faire.
  List<ProgressionAxis> get pending =>
      axes.where((axis) => !axis.known).toList(growable: false);
}

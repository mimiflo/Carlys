import 'package:flutter/widgets.dart';

/// Durées et courbes d'animation Carlys (tokens : motion.*).
///
/// Les ONZE durées de `tokens.json` sont ici, et nulle part ailleurs : un
/// composant qui écrit `Duration(milliseconds: 900)` contourne la source de
/// vérité, et le jour où le token bouge, il reste en arrière. Le test
/// `design_tokens_test.dart` compare cette classe au fichier de tokens.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration deliberate = Duration(milliseconds: 600);

  /// Cycle des animations d'ambiance en boucle (décoratives, jamais bloquantes).
  static const Duration ambient = Duration(milliseconds: 6000);

  /// Réaction d'une surface pressée (réponse de quiz, bouton) : assez
  /// courte pour se lire comme un retour du doigt, pas comme une animation.
  static const Duration tap = Duration(milliseconds: 120);

  /// Bascule d'un onglet de la barre basse (icône et libellé).
  static const Duration tab = Duration(milliseconds: 180);

  /// Transition entre deux pages. Branchée sur le thème ([AppTheme]) : le
  /// routeur n'a rien à savoir, chaque page poussée hérite de la durée.
  static const Duration route = Duration(milliseconds: 280);

  /// Remplissage d'un anneau ou d'une jauge, gravure d'un sceau : de zéro à
  /// la valeur, au premier affichage.
  static const Duration ring = Duration(milliseconds: 900);

  /// Un tour complet du segment voyageur d'une bordure animée.
  static const Duration dashLoop = Duration(milliseconds: 3400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve accelerate = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Respecte la préférence système de réduction des animations :
  /// utiliser cette méthode pour toute animation décorative.
  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

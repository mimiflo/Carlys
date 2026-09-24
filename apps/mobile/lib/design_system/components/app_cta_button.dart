import 'package:flutter/material.dart';

import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_gradient_action.dart';

/// L'APPEL À L'ACTION d'une barre ou d'une carte : l'unique geste que
/// l'écran met en avant — « Ajouter à la séance », « Valider la série »,
/// « Lancer », « Enregistrer ».
///
/// Le violet et la mécanique du bouton principal (`AppButton`) — c'est le
/// même `AppGradientAction` dessous, voile d'état sombre compris —, mais la
/// voix d'un appel : une icône, un libellé gras, le halo violet sous le
/// bouton, et toute la largeur que son parent lui donne (à poser dans un
/// parent qui la borne : `Expanded`, colonne étirée).
///
/// Il vivait en QUATRE copies écrites à la main dans les écrans, toutes sans
/// voile d'état : Material le dérivait du blanc du libellé, et le focus ou
/// l'appui ÉCLAIRCISSAIENT le dégradé sous le texte, jusque sous 4,5:1.
/// `ink_on_gradients_test.dart` refuse désormais la recette hors du design
/// system, et `contrast_pairs_test.dart` mesure chaque état de celui-ci.
///
/// Désactivé, le dégradé et son halo cèdent la place à la plaque de la
/// surface, libellé éteint. En chargement — désactivé, donc sur cette
/// plaque —, l'indicateur prend l'encre violette du thème, comme celui
/// d'un `AppButton` sans fond.
class AppCtaButton extends StatelessWidget {
  const AppCtaButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.glow = true,
    this.height,
    this.semanticLabel,
    this.loadingLabel = 'Chargement',
    super.key,
  });

  final String label;
  final IconData icon;

  /// `null` désactive le bouton.
  final VoidCallback? onPressed;

  /// Désactive le bouton et remplace son contenu par un indicateur.
  final bool isLoading;

  /// Le halo violet sous le bouton actif. Sans lui dans une barre basse,
  /// où il déborderait sur le verre dépoli.
  final bool glow;

  /// Hauteur minimale ; `null` garde celle du thème des boutons (48).
  final double? height;

  /// Ce que le lecteur d'écran annonce, quand le libellé visible ne suffit
  /// pas (« Lancer le modèle Push force » pour « Lancer »).
  final String? semanticLabel;

  /// Ce que le lecteur d'écran annonce pendant le chargement.
  final String loadingLabel;

  static const double _iconSize = 19;
  static const double _indicatorSize = 20;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final action = SizedBox(
      width: double.infinity,
      child: AppGradientAction(
        onPressed: _enabled ? onPressed : null,
        glow: glow,
        disabledLook: AppGradientActionDisabledLook.plate,
        style: FilledButton.styleFrom(
          minimumSize: height == null ? null : Size.fromHeight(height!),
          textStyle: AppTypography.subheading.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        child: isLoading ? _indicator(context) : _content(),
      ),
    );
    final announced = semanticLabel;
    if (announced == null) {
      return action;
    }
    return Semantics(
      button: true,
      enabled: _enabled,
      label: announced,
      child: action,
    );
  }

  Widget _content() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: _iconSize),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _indicator(BuildContext context) {
    return SizedBox(
      height: _indicatorSize,
      width: _indicatorSize,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.primary,
        semanticsLabel: loadingLabel,
      ),
    );
  }
}

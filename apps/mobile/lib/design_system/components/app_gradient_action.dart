import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../shadows/app_shadows.dart';

/// Comment une action au dégradé violet se montre DÉSACTIVÉE.
enum AppGradientActionDisabledLook {
  /// L'ensemble — dégradé ET libellé — s'éteint à moitié : un fond vif sous
  /// un libellé grisé se lit comme un bug d'affichage, pas comme un état.
  dimmed,

  /// Le dégradé cède la place à la plaque de la surface, libellé éteint :
  /// l'action se retire du décor jusqu'à ce qu'elle redevienne possible.
  plate,
}

/// LA MÉCANIQUE des boutons au dégradé violet : `AppButton` principal et
/// `AppCtaButton`. Interne au design system (non exportée par
/// `design_system.dart`) : un écran passe par l'un des deux, jamais par ce
/// qu'il y a dessous.
///
/// Le dégradé ([AppColors.cta]) se peint dans un [DecoratedBox] ; le
/// [FilledButton] posé dessus est rendu transparent, donc il n'apporte plus
/// que sa mécanique — dimensions du thème, effet de pression, sémantique,
/// zone tactile. Le rayon du fond suit celui du thème des boutons pour que
/// les coins du dégradé épousent ceux du bouton.
///
/// Le voile d'état est [stateVeil], SOMBRE : c'est tout l'objet de ce
/// fichier. `FilledButton.styleFrom` dérive sinon son voile du blanc du
/// libellé, et le survol, le focus et l'appui ÉCLAIRCISSENT le fond sous le
/// texte. La recette a longtemps vécu en cinq copies, dont quatre écrites à
/// la main dans les écrans, sans ce voile.
class AppGradientAction extends StatelessWidget {
  const AppGradientAction({
    required this.onPressed,
    required this.style,
    required this.child,
    this.glow = false,
    this.disabledLook = AppGradientActionDisabledLook.dimmed,
    super.key,
  });

  /// `null` désactive l'action.
  final VoidCallback? onPressed;

  /// Dimensions et typographie ; les couleurs sont fixées ici.
  final ButtonStyle style;
  final Widget child;

  /// Le halo violet sous l'action ([AppShadows.ctaGlow]), active seulement.
  final bool glow;
  final AppGradientActionDisabledLook disabledLook;

  /// Voile d'état (survol 8 %, focus et appui 10 %) des boutons PLEINS sous
  /// un libellé blanc — ceux-ci et le destructif d'`AppButton`. Sans lui,
  /// `styleFrom` le dérive du blanc du libellé, et l'état ÉCLAIRCIT le fond
  /// sous le texte jusque sous 4,5:1 au départ du dégradé ; sombre, il le
  /// fonce. `contrast_pairs_test.dart` mesure chaque état.
  static const Color stateVeil = AppColors.darkBackground;

  /// Le même voile, ÉTAT PAR ÉTAT, tel que Material le dérive pour ces
  /// boutons (survol 8 %, focus et appui 10 %) — pour un `InkWell` posé sur
  /// un dégradé. Sans lui, l'`InkWell` prend les voiles gris CLAIRS du thème,
  /// qui éclaircissent le dégradé sous l'icône blanche.
  static final WidgetStateProperty<Color?> stateOverlay =
      FilledButton.styleFrom(overlayColor: stateVeil).overlayColor!;

  /// Le libellé d'une action désactivée posée sur sa plaque.
  static const Color _plateInk = AppColors.darkIconInactive;

  static const double _dimmedOpacity = 0.45;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final plate =
        !enabled && disabledLook == AppGradientActionDisabledLook.plate;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: plate ? null : AppColors.cta,
        color: plate ? Theme.of(context).colorScheme.surface : null,
        borderRadius: AppRadius.buttonAll,
        boxShadow: glow && enabled ? AppShadows.ctaGlow() : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: style.merge(
          FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.neutral0,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: plate ? _plateInk : AppColors.neutral0,
            overlayColor: stateVeil,
            shadowColor: Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
    return switch (disabledLook) {
      // L'opacité seule tamise ; les couleurs « disabled » restent pleines
      // pour que ce soit le dégradé ET le texte qui pâlissent d'un même
      // mouvement.
      AppGradientActionDisabledLook.dimmed => Opacity(
        opacity: enabled ? 1 : _dimmedOpacity,
        child: surface,
      ),
      AppGradientActionDisabledLook.plate => surface,
    };
  }
}

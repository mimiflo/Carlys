import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Bas de l'onboarding : pastille accent pleine largeur, lien « Passer » et,
/// avant toute session, entrée vers la connexion.
///
/// Le CTA reste éteint tant que l'étape n'a pas de réponse : c'est le seul
/// aplat lime de l'écran.
class OnboardingCta extends StatelessWidget {
  const OnboardingCta({
    required this.label,
    required this.onPressed,
    required this.onSkip,
    this.onLogin,
    this.loading = false,
    super.key,
  });

  final String label;

  /// `null` désactive la pastille (aucune réponse choisie).
  final VoidCallback? onPressed;
  final VoidCallback onSkip;

  /// `null` quand une session est déjà ouverte : le lien n'a alors aucun sens.
  final VoidCallback? onLogin;
  final bool loading;

  /// Géométrie de la maquette : padding 17, flèche 19.
  static const double _paddingAll = 17;
  static const double _arrowSize = 19;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final foreground =
        _enabled ? AppColors.darkBackground : AppColors.darkTextTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: _enabled,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? onPressed : null,
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.fast),
              curve: AppMotion.standard,
              padding: const EdgeInsets.all(_paddingAll),
              decoration: BoxDecoration(
                color: _enabled ? AppColors.accent : AppColors.darkSurfaceAlt,
                borderRadius: AppRadius.buttonAll,
                boxShadow: _enabled ? _accentGlow : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppTypography.subheading.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (loading)
                    SizedBox(
                      width: _arrowSize,
                      height: _arrowSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                        semanticsLabel: 'Enregistrement',
                      ),
                    )
                  else
                    // Absente d'AppIcons : même glyphe que la maquette.
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: _arrowSize,
                      color: foreground,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        // Wrap : passe à la ligne sur les écrans étroits ou avec une grande
        // taille de police système, au lieu de déborder.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: loading ? null : onSkip,
              child: Text('Passer', style: _linkStyle),
            ),
            if (onLogin != null)
              TextButton(
                onPressed: loading ? null : onLogin,
                child: Text('J’ai déjà un compte', style: _linkStyle),
              ),
          ],
        ),
      ],
    );
  }

  static final TextStyle _linkStyle =
      AppTypography.label.copyWith(color: AppColors.darkTextTertiary);

  /// Halo lime sous la pastille (ombre de la maquette).
  static final List<BoxShadow> _accentGlow = [
    BoxShadow(
      color: AppColors.accent.withValues(alpha: 0.5),
      offset: const Offset(0, 12),
      blurRadius: 30,
      spreadRadius: -12,
    ),
  ];
}

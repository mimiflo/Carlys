import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../spacing/app_spacing.dart';
import 'app_button.dart';

/// État d'erreur standard : icône, titre, message et action de réessai.
///
/// LES COULEURS SONT CELLES DU FOND SOMBRE, pas celles du thème. Les écrans
/// qui accueillent cet état peignent leur `Scaffold` en
/// `AppColors.darkBackground` — quarante-cinq fichiers le font, l'application
/// est sombre par dessin. Or ce composant lisait `Theme.of(context)`, dont
/// l'`onSurface` vaut `neutral900` sous le thème Clair : titre et message
/// s'écrivaient alors en quasi-noir sur ce fond sombre, illisibles. Il n'y a
/// qu'un seul fond possible derrière cet état ; autant le dire.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Réessayer',
    this.icon = AppIcons.error,
    super.key,
  });

  /// LA phrase d'un échec réseau ou serveur, partagée par tous les écrans
  /// qui n'ont rien de plus précis à dire. Elle vit ici, une fois, au
  /// tutoiement de l'application : recopiée dans sept écrans, elle avait
  /// dérivé vers le vouvoiement pendant que le composant hors ligne, lui,
  /// tutoyait.
  static const String retryConnectionMessage =
      'Vérifie ta connexion puis réessaie.';

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: retryLabel,
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
                icon: AppIcons.retry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

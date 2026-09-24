import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';

/// Boucler un domaine se FÊTE, une fois.
///
/// Rien ne se déclenchait depuis l'Academy : on pouvait aborder la dernière
/// leçon d'un domaine sans que l'application le remarque. Le bandeau reprend
/// la grammaire du franchissement de titre — dégradé de signature, sceau
/// gravé, dépliement plutôt que superposition — parce que c'est le même
/// genre d'événement : rare, mérité, et qui ne se reprend pas.
///
/// La signature est celle qui porte un texte ([AppColors.signatureInk]), et
/// chaque texte est en blanc PLEIN : sur la signature d'origine, le surtitre
/// à 80 % tombait à 3,31:1 et la croix de fermeture à 2,59, sur l'orange.
///
/// Il se déplie une seule fois, au moment du franchissement : l'écran le
/// pose à partir d'une comparaison avant/après, jamais depuis l'état final.
/// Une fête qui reviendrait à chaque ouverture ne célébrerait plus rien.
class DomainCompletedBanner extends StatelessWidget {
  const DomainCompletedBanner({
    required this.domaine,
    required this.onDismiss,
    super.key,
  });

  final AcademyCategory domaine;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.resolve(context, AppMotion.reveal),
      curve: AppMotion.emphasized,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: child,
        ),
      ),
      child: Semantics(
        label: 'Domaine bouclé : ${domaine.label}',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.signatureInk,
            borderRadius: AppRadius.lgAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(
                  AppIcons.record,
                  size: 28,
                  color: AppColors.neutral0,
                ),
                const SizedBox(width: AppSpacing.gapRow),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Domaine bouclé',
                        style: AppTypography.label.copyWith(
                          color: AppColors.neutral0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        domaine.label,
                        style: AppTypography.title.copyWith(
                          color: AppColors.neutral0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Fermer',
                  icon: const Icon(
                    AppIcons.close,
                    size: 20,
                    color: AppColors.neutral0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

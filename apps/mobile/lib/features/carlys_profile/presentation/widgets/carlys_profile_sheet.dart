import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';
import 'carlys_profile_content.dart';

/// Fiche d'un profil : devise, publics (« Pour »), et le geste de choix.
/// Rend `true` si la personne choisit ce profil, `null` sinon.
Future<bool?> showCarlysProfileSheet(
  BuildContext context, {
  required CarlysProfile profile,
  required bool isCurrent,
}) {
  return showAppSheet<bool>(
    context,
    builder: (_) => _ProfileSheet(profile: profile, isCurrent: isCurrent),
  );
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({required this.profile, required this.isCurrent});

  final CarlysProfile profile;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final content = carlysProfileContentOf(profile);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(content.title.toUpperCase(), style: AppTypography.heading),
          const SizedBox(height: AppSpacing.xs),
          Text(
            content.quote,
            style: AppTypography.quote.copyWith(color: AppColors.primaryLight),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppSectionLabel('Pour'),
          const SizedBox(height: AppSpacing.xs),
          for (final line in content.audience)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(line, style: AppTypography.body)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Un profil n’est pas un niveau : tu peux en changer '
            'à tout moment.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isCurrent)
            const AppButton(
              label: 'C’est ton profil actuel',
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: null,
            )
          else
            AppButton(
              label: 'Choisir ce profil',
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';
import 'carlys_profile_content.dart';
import 'profile_medallion.dart';

/// Fiche d'un profil (maquette d'octobre 2026) : le médaillon, la devise,
/// la description, « Pour toi si… », et le geste de choix.
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(title: content.title, tagline: 'Ta façon d’avancer'),
          if (isCurrent) ...[
            const SizedBox(height: AppSpacing.xs),
            const Center(
              child: AppBadge(
                label: 'Ton profil',
                variant: AppBadgeVariant.primary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(child: ProfileMedallion(content: content, size: 112)),
          const SizedBox(height: AppSpacing.md),
          Text(
            content.quote,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: AppColors.primaryLight),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            content.tagline,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PourToiSi(lignes: content.audience),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Un profil n’est pas un niveau : tu peux en changer '
            'à tout moment.',
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isCurrent)
            const AppButton(
              label: 'C’est ton profil actuel',
              icon: AppIcons.checkCircle,
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

/// Ce que le profil sert, une ligne chacun. Sans chevron : ces lignes se
/// lisent, elles ne mènent nulle part.
class _PourToiSi extends StatelessWidget {
  const _PourToiSi({required this.lignes});

  final List<String> lignes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionLabel('Pour toi si…'),
          for (final (index, ligne) in lignes.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.rowDivider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                ligne,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

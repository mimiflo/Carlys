import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../controllers/nutrition_controllers.dart';
import '../widgets/metabolic_profile_form.dart';
import '../widgets/metabolism_hero.dart';
import '../widgets/metabolism_view.dart';

/// Nutrition (maquette 2b) : hero métabolisme sur hélice ADN, macros en
/// jauges, profil complété sur place — calculs côté serveur uniquement.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(metabolismReportProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: report.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Analyse du métabolisme'),
          error: (_, __) => AppErrorState(
            title: 'Métabolisme indisponible',
            message: 'Vérifiez votre connexion puis réessayez.',
            onRetry: () => ref.invalidate(metabolismReportProvider),
          ),
          data: (data) => _NutritionContent(report: data),
        ),
      ),
    );
  }
}

class _NutritionContent extends StatelessWidget {
  const _NutritionContent({required this.report});

  final MetabolismReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metabolism = report.metabolism;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.gutter + bottomInset,
      ),
      children: [
        MetabolismHero(metabolism: metabolism),
        const SizedBox(height: AppSpacing.md),
        if (metabolism != null) ...[
          MetabolismView(profile: report.profile, metabolism: metabolism),
          const SizedBox(height: AppSpacing.gapSection),
          Text(
            'Mon profil',
            style: AppTypography.heading
                .copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          MetabolicProfileForm(profile: report.profile),
        ] else ...[
          _MissingFieldsCard(missing: report.missing),
          const SizedBox(height: AppSpacing.md),
          MetabolicProfileForm(profile: report.profile),
        ],
      ],
    );
  }
}

class _MissingFieldsCard extends StatelessWidget {
  const _MissingFieldsCard({required this.missing});

  final List<MetabolismMissingField> missing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations manquantes',
            style: AppTypography.heading
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final field in missing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: AppColors.darkTextTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    field.label,
                    style: AppTypography.body
                        .copyWith(color: AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

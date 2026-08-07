import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../controllers/nutrition_controllers.dart';
import '../widgets/dna_helix.dart';
import '../widgets/metabolic_profile_form.dart';
import '../widgets/metabolism_view.dart';

/// Nutrition : métabolisme calculé côté serveur, profil complété sur place.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(metabolismReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      body: SafeArea(
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

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          child: Column(
            children: [
              const DnaHelix(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Votre métabolisme',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                metabolism == null
                    ? 'Complétez votre profil pour calculer vos besoins '
                        'quotidiens — calculs faits sur nos serveurs.'
                    : 'Besoins estimés par la formule de Mifflin-St Jeor, '
                        'à partir de votre dernière pesée.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (metabolism != null) ...[
          MetabolismView(profile: report.profile, metabolism: metabolism),
          const SizedBox(height: AppSpacing.lg),
          Text('Mon profil', style: theme.textTheme.titleLarge),
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
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations manquantes', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final field in missing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(field.label, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

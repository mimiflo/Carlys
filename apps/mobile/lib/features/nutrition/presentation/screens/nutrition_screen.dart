import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/scene_scroll_activity.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/entities/nutrition.dart';
import '../controllers/nutrition_controllers.dart';
import '../widgets/meal_journal_section.dart';
import '../widgets/metabolic_profile_form.dart';
import '../widgets/metabolism_hero.dart';
import '../widgets/metabolism_view.dart';
import '../widgets/missing_profile_card.dart';

/// Nutrition (maquette 2g) : hero métabolisme sur hélice ADN, macros en
/// jauges, journal du jour, profil complété sur place — calculs côté serveur
/// uniquement. Le journal est la moitié RÉELLE du « consommé / objectif »
/// de l'accueil : rien n'y est inventé, tout vient de la saisie.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(metabolismReportProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          report.when(
            loading: () => const SafeArea(
              child: AppLoadingIndicator(label: 'Analyse du métabolisme'),
            ),
            error: (error, _) => SafeArea(
              child: ConnectionAwareError(
                error: error,
                title: 'Métabolisme indisponible',
                message: 'Le rapport n’a pas pu être calculé. Réessaie.',
                offlineMessage: 'Le métabolisme se calcule sur le serveur : '
                    'il revient avec le réseau.',
                onRetry: () => ref.invalidate(metabolismReportProvider),
              ),
            ),
            // L'hélice se fige pendant le défilement, comme le cœur à
            // l'accueil.
            data: (data) => SceneScrollActivity(
              child: _NutritionContent(report: data),
            ),
          ),
          // Le hero est à fond perdu : la flèche de retour se pose PAR-DESSUS,
          // dans la zone sûre, comme sur une fiche d'exercice.
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs),
              child: Align(
                alignment: Alignment.topLeft,
                child: AppBackButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionContent extends StatelessWidget {
  const _NutritionContent({required this.report});

  final MetabolismReport report;

  @override
  Widget build(BuildContext context) {
    final metabolism = report.metabolism;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return ListView(
      // Le hero est à fond perdu : chaque section pose sa propre gouttière.
      padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.gapSection),
      children: [
        MetabolismHero(metabolism: metabolism),
        if (metabolism != null)
          _Section(child: MetabolismView(metabolism: metabolism))
        else
          _Section(child: _MissingSection(missing: report.missing)),
        const SizedBox(height: AppSpacing.gapSection),
        _Section(
          child: MealJournalSection(targetKcal: metabolism?.targetKcal),
        ),
        const SizedBox(height: AppSpacing.gapSection),
        const _Section(child: AppSectionHeader(title: 'Mon profil')),
        const SizedBox(height: AppSpacing.sm),
        _Section(child: MetabolicProfileForm(profile: report.profile)),
      ],
    );
  }
}

/// Champs manquants : ce que le serveur attend pour calculer le métabolisme.
class _MissingSection extends StatelessWidget {
  const _MissingSection({required this.missing});

  final List<MetabolismMissingField> missing;

  @override
  Widget build(BuildContext context) {
    final count = formatThousands(missing.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Informations manquantes',
          trailing: '$count champ${missing.length > 1 ? 's' : ''}',
        ),
        const SizedBox(height: AppSpacing.sm),
        MissingProfileCard(missing: missing),
      ],
    );
  }
}

/// Gouttière d'écran commune aux sections posées sous le hero.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: child,
    );
  }
}

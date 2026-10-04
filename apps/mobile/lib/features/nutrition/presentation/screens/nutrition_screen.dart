import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/illustrated_banner.dart';
import '../providers/journal_day_provider.dart';
import '../widgets/journal_day_chip.dart';
import '../widgets/meal_journal_section.dart';
import '../widgets/nutrition_shortcuts.dart';
import '../widgets/today_goals.dart';

/// L'onglet Nutrition (maquette d'octobre 2026) : le jour, les objectifs du
/// jour (mangé sur visé), les quatre gestes, le journal illustré, puis le
/// coach. Le détail du calcul — dépense, corps, profil — vit sur « Mon
/// métabolisme ». Rien n'y est inventé : le journal vient de la saisie, les
/// objectifs du serveur.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(journalDayProvider);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: ListView(
        // LE scrollable de la page, attaché au contrôleur primaire : le tap
        // sur la barre d'état iOS la remonte.
        primary: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          MediaQuery.paddingOf(context).top + AppSpacing.md,
          AppSpacing.md,
          bottomInset + AppSpacing.gapSection,
        ),
        children: [
          const AppScreenHeader(
            title: 'Nutrition',
            tagline: 'Mange mieux, vis mieux',
            showBack: false,
            actions: [JournalDayChip()],
          ),
          const SizedBox(height: AppSpacing.md),
          const TodayGoals(),
          const SizedBox(height: AppSpacing.md),
          NutritionShortcuts(day: day),
          const SizedBox(height: AppSpacing.gapSection),
          const MealJournalSection(),
          const SizedBox(height: AppSpacing.gapSection),
          // Le coach compose avec les objectifs du profil : la vraie porte
          // vers « plus facilement », pas une offre de plus.
          IllustratedBanner(
            title: 'Atteins tes objectifs plus facilement',
            body:
                'Le coach compose tes repas avec tes objectifs et ce que tu '
                'as sous la main.',
            onTap: () => context.push(AppRoutes.coach),
          ),
        ],
      ),
    );
  }
}

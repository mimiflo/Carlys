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

/// L'ordre des sections dépend d'UNE chose : le profil est-il complet ?
///
/// Complet, le journal vient avant le formulaire, qu'on ne retouche plus
/// guère. Incomplet, le formulaire REMONTE au-dessus du journal : le seul
/// geste utile du premier jour ne doit pas être le dernier bloc de la page,
/// et le bouton du hero doit pouvoir y mener d'un coup.
class _NutritionContent extends StatefulWidget {
  const _NutritionContent({required this.report});

  final MetabolismReport report;

  @override
  State<_NutritionContent> createState() => _NutritionContentState();
}

class _NutritionContentState extends State<_NutritionContent> {
  final _profileKey = GlobalKey();

  /// Amène le formulaire en haut de l'écran.
  ///
  /// La liste est paresseuse : si le bloc n'est pas encore construit, on
  /// descend d'abord, puis on cale — jamais un bouton qui ne fait rien.
  Future<void> _revealProfile() async {
    final duration = AppMotion.resolve(context, AppMotion.slow);
    final target = _profileKey.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: duration,
        curve: AppMotion.standard,
      );
      return;
    }
    // Le défilement passe par le contrôleur PRIMAIRE de la route : celui
    // auquel le ListView est attaché (voir build), donc celui que le tap
    // sur la barre d'état iOS pilote aussi. `moveTo` saute sans animation
    // quand la réduction d'animations donne une durée nulle.
    final position = PrimaryScrollController.of(context).position;
    await position.moveTo(
      position.maxScrollExtent,
      duration: duration,
      curve: AppMotion.standard,
    );
    final built = _profileKey.currentContext;
    if (built != null && built.mounted) {
      await Scrollable.ensureVisible(
        built,
        duration: duration,
        curve: AppMotion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final metabolism = report.metabolism;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;
    final profile = KeyedSubtree(
      key: _profileKey,
      child: _ProfileBlock(profile: report.profile),
    );
    final journal = _Section(
      child: MealJournalSection(targetKcal: metabolism?.targetKcal),
    );

    return ListView(
      // LE scrollable de la page : attaché au contrôleur primaire de la
      // route, pas à un contrôleur privé — un contrôleur propre retirait
      // l'écran du PrimaryScrollController et le tap sur la barre d'état
      // iOS ne remontait plus la liste.
      primary: true,
      // Le hero est à fond perdu : chaque section pose sa propre gouttière.
      padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.gapSection),
      children: [
        MetabolismHero(
          metabolism: metabolism,
          onCompleteProfile: _revealProfile,
        ),
        if (metabolism != null) ...[
          _Section(child: MetabolismView(metabolism: metabolism)),
          const SizedBox(height: AppSpacing.gapSection),
          journal,
          const SizedBox(height: AppSpacing.gapSection),
          profile,
        ] else ...[
          _Section(child: _MissingSection(missing: report.missing)),
          const SizedBox(height: AppSpacing.gapSection),
          profile,
          const SizedBox(height: AppSpacing.gapSection),
          journal,
        ],
      ],
    );
  }
}

/// « Mon profil » : l'en-tête et le formulaire, toujours ensemble.
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.profile});

  final MetabolicProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Section(child: AppSectionHeader(title: 'Mon profil')),
        const SizedBox(height: AppSpacing.sm),
        _Section(child: MetabolicProfileForm(profile: profile)),
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

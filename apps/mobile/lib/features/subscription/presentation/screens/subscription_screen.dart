import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../controllers/subscription_controllers.dart';
import '../widgets/subscription_benefits.dart';
import '../widgets/subscription_hero.dart';
import '../widgets/subscription_plan_card.dart';

/// Abonnement (maquette 2i) : plein écran sans barre de titre, cœur ambiant
/// débordant en haut à droite, accroche premium, avantages issus des droits
/// réels puis carte du plan.
///
/// La maquette montre deux cartes d'offre chiffrées et un bouton d'achat :
/// l'API ne sert aucun catalogue de prix ni action d'achat, ces blocs sont
/// donc omis plutôt qu'inventés.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planStatusProvider);
    final entitlements = ref.watch(entitlementsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Cœur ambiant haut-droite, débordant du cadre (2i).
          const Positioned(
            top: 14,
            right: -118,
            child: AppSceneContainer(
              size: 300,
              opacity: 0.55,
              verticalFadeStops: [0.0, 0.22, 0.58, 0.90],
              child: HeartScene(),
            ),
          ),
          // Ordre de la maquette : assombrissement latéral puis halo violet
          // par-dessus, sans quoi le coin haut-droit vire au gris.
          const Positioned.fill(child: AppSceneScrim.lateral()),
          const Positioned.fill(
            child: AppSceneGlow(
              center: Alignment(0.64, -0.72),
              radius: 0.62,
              alpha: 0.30,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CloseButton(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.gapSection,
                    ),
                    children: [
                      const SubscriptionHero(),
                      const SizedBox(height: AppSpacing.gapSection),
                      entitlements.when(
                        loading: () => const AppLoadingIndicator(
                          label: 'Chargement des droits',
                        ),
                        error: (_, __) => AppErrorState(
                          title: 'Droits indisponibles',
                          onRetry: () => ref.invalidate(entitlementsProvider),
                        ),
                        data: (entries) => SubscriptionBenefits(
                          entries: entries,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gapSection),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter,
                        ),
                        child: plan.when(
                          loading: () => const AppLoadingIndicator(
                            label: 'Chargement du plan',
                          ),
                          error: (_, __) => AppErrorState(
                            title: 'Plan indisponible',
                            onRetry: () => ref.invalidate(planStatusProvider),
                          ),
                          data: (status) => SubscriptionPlanCard(
                            status: status,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _PurchaseNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Croix de fermeture de la maquette, calée sur la gouttière : la gouttière
/// moins la demi-boîte tactile place l'icône exactement sur la marge.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  static const double _iconSize = 23;
  static const double _tapSize = 44;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          top: AppSpacing.xs,
        ),
        child: IconButton(
          tooltip: 'Fermer',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: _tapSize,
            height: _tapSize,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.profile),
          icon: const Icon(
            AppIcons.close,
            size: _iconSize,
            color: AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Bas d'écran de la maquette : la mention légale reste, le bouton d'achat
/// attend un catalogue de prix et une action de paiement côté serveur.
class _PurchaseNote extends StatelessWidget {
  const _PurchaseNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Text(
        'La souscription se fait via l’App Store, Google Play ou le site web. '
        'Vos droits sont toujours validés par le serveur — la restauration '
        'd’achat les réactive automatiquement.',
        textAlign: TextAlign.center,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          height: 1.4,
          color: AppColors.darkTextTertiary,
        ),
      ),
    );
  }
}

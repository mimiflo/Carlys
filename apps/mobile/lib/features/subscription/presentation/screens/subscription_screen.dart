import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../../../../design_system/scenes/scene_scroll_activity.dart';
import '../../../onboarding/domain/first_run_step.dart';
import '../../../onboarding/presentation/controllers/first_run_controller.dart';
import '../controllers/subscription_controllers.dart';
import '../widgets/first_run_premium_footer.dart';
import '../widgets/subscription_benefits.dart';
import '../widgets/subscription_hero.dart';
import '../widgets/subscription_manage_row.dart';
import '../widgets/subscription_plan_card.dart';
import '../widgets/subscription_purchase_note.dart';
import '../widgets/subscription_purchase_panel.dart';
import '../widgets/subscription_resume_listener.dart';

/// Abonnement (maquette 2i) : plein écran sans barre de titre, cœur ambiant
/// débordant en haut à droite, accroche premium, avantages issus des droits
/// réels puis carte du plan.
///
/// Les deux cartes d'offre de la maquette et le bouton d'achat sont là : les
/// prix viennent du serveur (`GET /subscriptions/offers`) et le bouton ouvre
/// une page de paiement. Rien n'est chiffré côté application, et aucun droit
/// n'est accordé au retour : c'est le webhook signé qui l'accorde. Au retour
/// dans l'application, le plan et les droits sont RELUS
/// (`SubscriptionResumeListener`), jamais supposés.
///
/// Le même écran sert de temps d'arrêt au parcours de première ouverture :
/// il n'est alors pas refermable, et son bas d'écran propose Premium puis,
/// en cas de refus, la version gratuite (`FirstRunPremiumFooter`).
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planStatusProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final firstRun =
        ref.watch(firstRunStepProvider) == FirstRunStep.subscription;

    return SubscriptionResumeListener(
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        // Le cœur ambiant se fige pendant le défilement de l'écran.
        body: SceneScrollActivity(
          child: Stack(
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
                    // Pendant le parcours, l'écran ne se referme pas : la sortie
                    // passe par le bas d'écran (Premium ou version gratuite).
                    if (firstRun)
                      const SizedBox(height: AppSpacing.lg)
                    else
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
                              onRetry: () =>
                                  ref.invalidate(entitlementsProvider),
                            ),
                            data: (entries) =>
                                SubscriptionBenefits(entries: entries),
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
                                onRetry: () =>
                                    ref.invalidate(planStatusProvider),
                              ),
                              data: (status) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SubscriptionPlanCard(status: status),
                                  // Une fois Premium, ce qui se gère chez le
                                  // prestataire : moyen de paiement,
                                  // factures, résiliation.
                                  if (status.isPremium) ...[
                                    const SizedBox(height: AppSpacing.gapRow),
                                    const SubscriptionManageRow(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // Les offres vivent DANS la page : mises en pied
                          // fixe, elles écraseraient la partie qui explique
                          // Premium, juste au-dessus.
                          if (!firstRun) ...[
                            const SizedBox(height: AppSpacing.gapSection),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.gutter,
                              ),
                              child: SubscriptionPurchasePanel(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (firstRun)
                      const FirstRunPremiumFooter()
                    else
                      const _PurchaseNote(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Croix de fermeture de la maquette, calée sur la gouttière. L'icône garde
/// la taille de la maquette ; la boîte qui répond au doigt est
/// [AppSpacing.touchTarget], la seule cible tactile de l'application.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  static const double _iconSize = 23;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
        child: IconButton(
          tooltip: 'Fermer',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
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

/// Bas d'écran : la mention légale. Les offres, elles, sont dans la page.
class _PurchaseNote extends StatelessWidget {
  const _PurchaseNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: SubscriptionPurchaseNote(),
    );
  }
}

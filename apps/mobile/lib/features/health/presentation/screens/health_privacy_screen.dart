import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/external_links.dart';
import '../../../../design_system/design_system.dart';

/// « Pourquoi Carlys lit tes données de santé » — l'écran que Health
/// Connect ouvre depuis sa page d'autorisations (lien « Règles de
/// confidentialité »), comme Google Play l'exige.
///
/// Joignable SANS session (`AppRoutes.healthPrivacy`, hors des redirections
/// du routeur) : Health Connect peut l'ouvrir alors que personne n'est
/// connecté. Il dit ce qui est lu, ce qui part au serveur, et mène à la
/// politique de confidentialité complète, qui vit sur le web.
class HealthPrivacyScreen extends ConsumerWidget {
  const HealthPrivacyScreen({super.key});

  static const List<(IconData, String, String)> _facts = [
    (
      AppIcons.steps,
      'Tes pas du jour',
      'Affichés sur l’accueil. Ils restent sur ton téléphone : aucun envoi.',
    ),
    (
      AppIcons.bodyMetrics,
      'Tes pesées : poids et masse grasse',
      'Ajoutées à tes mesures Carlys, envoyées au serveur comme une saisie '
          'à la main, et supprimables comme elles.',
    ),
    (
      AppIcons.privacy,
      'Lecture seule',
      'Carlys n’écrit rien dans Health Connect ni dans Apple Santé, et ne '
          'lit rien d’autre. Tu peux couper la connexion dans les réglages.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            const AppScreenHeader(
              title: 'Santé connectée',
              tagline: 'Ce que Carlys lit, et pourquoi.',
              showBack: false,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (icon, title, detail) in _facts) ...[
              _Fact(icon: icon, title: title, detail: detail),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Lire la politique de confidentialité',
              isExpanded: true,
              onPressed: () => openExternalLink(
                environment.privacyPolicyUrl,
                ref: ref,
                notices: AppNotices.of(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Ouvrir Carlys',
              variant: AppButtonVariant.ghost,
              isExpanded: true,
              onPressed: () => context.go(AppRoutes.splash),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une donnée lue : son glyphe sur sa plaque, son nom, ce qu'il en advient.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: icon, background: AppColors.surfaceIcon),
          const SizedBox(width: AppSpacing.gapRow),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../carlys_profile/presentation/widgets/carlys_profile_content.dart';

/// Le CAP du profil : la carte de l'accueil qui change avec l'identité
/// Carlys — chaque profil est orienté vers la partie de l'application qui
/// sert sa devise (Académie, défis, programmes, progression).
///
/// Absente tant qu'aucun profil n'est choisi : `null` signifie « pas de
/// personnalisation », jamais un profil par défaut.
class ProfileFocusCard extends StatelessWidget {
  const ProfileFocusCard({required this.profile, super.key});

  final CarlysProfile profile;

  @override
  Widget build(BuildContext context) {
    final content = carlysProfileContentOf(profile);
    final focus = _focusOf(profile);

    return AppCard(
      onTap: () => focus.open(context),
      // Ne JAMAIS commencer ce libellé par « Profil » : l'avatar de
      // l'en-tête s'annonce ainsi et les tests naviguent dessus.
      semanticLabel: 'Ton cap ${content.title} : ${focus.title}',
      child: Row(
        children: [
          Icon(content.icon, color: AppColors.primaryLight),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionLabel('Ton cap ${content.title}'),
                const SizedBox(height: AppSpacing.xxs),
                Text(focus.title, style: AppTypography.subheading),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  focus.body,
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}

/// Copie et destination du cap — propres à l'accueil, donc définies ici et
/// pas dans le contenu éditorial des profils (qui ignore la navigation).
class _ProfileFocus {
  const _ProfileFocus({
    required this.title,
    required this.body,
    required this.open,
  });

  final String title;
  final String body;

  /// `go` vers une branche de la barre d'onglets, `push` vers un plein écran.
  final void Function(BuildContext context) open;
}

_ProfileFocus _focusOf(CarlysProfile profile) {
  return switch (profile) {
    CarlysProfile.constructeur => _ProfileFocus(
        title: 'Pose tes fondations',
        body: 'L’Académie t’explique les mouvements, la nutrition et les '
            'bases — apprends en t’entraînant.',
        open: (context) => context.go(AppRoutes.academy),
      ),
    CarlysProfile.challenger => _ProfileFocus(
        title: 'Va chercher un défi',
        body: 'La communauté lance des défis à ta hauteur : sors de ta zone '
            'de confort cette semaine.',
        open: (context) => context.go(AppRoutes.community),
      ),
    CarlysProfile.athlete => _ProfileFocus(
        title: 'Tiens ton plan',
        body: 'Un programme sur plusieurs semaines transforme ta discipline '
            'en résultats mesurables.',
        open: (context) => context.push(AppRoutes.programs),
      ),
    CarlysProfile.stratege => _ProfileFocus(
        title: 'Comprends tes chiffres',
        body: 'Records, tendances, mesures : lis ce que ton corps répond '
            'avant de décider la suite.',
        open: (context) => context.go(AppRoutes.progress),
      ),
  };
}

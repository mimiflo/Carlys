import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/carlys_profile.dart';
import '../providers/carlys_profile_providers.dart';
import '../widgets/carlys_profile_card.dart';
import '../widgets/carlys_profile_sheet.dart';

/// Les 4 profils Carlys — des identités d'usage, jamais des niveaux.
///
/// La sélection affichée vient de `AuthUser.carlysProfile` (source unique) ;
/// choisir écrit au serveur puis rafraîchit l'utilisateur. Un échec n'est
/// jamais silencieux : il s'affiche, le profil courant reste inchangé.
class CarlysProfilesScreen extends ConsumerWidget {
  const CarlysProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(authControllerProvider).user?.carlysProfile;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            const AppScreenHeader.centered(
              title: 'Profil Carlys',
              tagline: 'Ta façon d’avancer',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Quatre identités, pas des niveaux. Choisis celle qui te '
              'ressemble aujourd’hui.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final profile in CarlysProfile.values) ...[
              CarlysProfileCard(
                profile: profile,
                isCurrent: profile == current,
                onTap: () => _openSheet(context, ref, profile, current),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tu peux changer de profil à tout moment.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    CarlysProfile profile,
    CarlysProfile? current,
  ) async {
    final chosen = await showCarlysProfileSheet(
      context,
      profile: profile,
      isCurrent: profile == current,
    );
    if (chosen != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(carlysProfileActionsProvider).choose(profile);
    } on AppException catch (exception) {
      if (context.mounted) {
        AppNotices.of(
          context,
        ).show(exception.message, tone: AppNoticeTone.error);
      }
    }
  }
}

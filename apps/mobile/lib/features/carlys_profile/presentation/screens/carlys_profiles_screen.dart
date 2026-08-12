import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/entities/carlys_profile.dart';
import '../controllers/carlys_profile_controllers.dart';
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
    final authState = ref.watch(authControllerProvider);
    final current = switch (authState) {
      AuthAuthenticated(:final user) => user?.carlysProfile,
      _ => null,
    };
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Profil Carlys')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            Text(
              'Quatre identités, pas des niveaux : un débutant peut être '
              'Stratège, un sportif avancé Challenger — et tu peux changer '
              'à tout moment.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final profile in CarlysProfile.values) ...[
              CarlysProfileCard(
                profile: profile,
                isCurrent: profile == current,
                onTap: () => _openSheet(context, ref, profile, current),
              ),
              const SizedBox(height: AppSpacing.gapTile),
            ],
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }
  }
}

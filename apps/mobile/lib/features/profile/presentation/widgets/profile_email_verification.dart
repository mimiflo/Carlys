import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../authentication/presentation/controllers/account_controllers.dart';
import '../../../authentication/presentation/widgets/auth_form_error.dart';

/// Rappel sobre : l'adresse e-mail n'a jamais été vérifiée.
///
/// Il n'apparaît QUE dans ce cas, et disparaît au rafraîchissement du profil
/// une fois l'adresse validée. Ce n'est ni une alerte ni un blocage : rien
/// dans l'application n'est fermé tant que l'adresse n'est pas vérifiée, mais
/// c'est elle qui permettra de récupérer le compte, donc autant le dire.
///
/// Le serveur répond pareil que l'adresse soit déjà vérifiée ou non
/// (`POST /auth/resend-verification` → 204) : on confirme donc l'envoi, on ne
/// prétend jamais savoir ce qu'il a fait.
class ProfileEmailVerification extends ConsumerWidget {
  const ProfileEmailVerification({required this.user, super.key});

  /// Null tant que le profil n'est pas chargé : rien ne s'affiche alors,
  /// plutôt qu'un rappel qui se démentirait une seconde plus tard.
  final AuthUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = user;
    if (current == null || current.emailVerified) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(emailVerificationControllerProvider);
    final theme = Theme.of(context);
    final sent = state.valueOrNull == true;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.emailUnverified,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adresse e-mail non vérifiée',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  sent
                      ? 'C’est envoyé. Ouvre le lien depuis ta boîte de '
                            'réception : il te ramènera sur une page web qui '
                            'valide ton adresse.'
                      : 'Vérifie ${current.email} pour pouvoir récupérer ton '
                            'compte si tu perds ton mot de passe.',
                  style: theme.textTheme.bodySmall,
                ),
                if (state.hasError) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      authErrorMessage(state.error!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (!sent) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'Renvoyer l’e-mail',
                    variant: AppButtonVariant.secondary,
                    isLoading: state.isLoading,
                    onPressed: () => ref
                        .read(emailVerificationControllerProvider.notifier)
                        .resend(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

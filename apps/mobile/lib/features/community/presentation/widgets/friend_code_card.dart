import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/friend_code.dart';
import '../controllers/community_controllers.dart';

/// « Mon code » : le QR à faire scanner et le code à dicter.
///
/// Le QR vit sur un aplat BLANC quel que soit le thème : un lecteur de
/// code veut du contraste, pas de l'ambiance — c'est le seul endroit de
/// l'application où le fond ne suit pas la surface.
class FriendCodeCard extends ConsumerWidget {
  const FriendCodeCard({super.key});

  static const double _qrSide = 132;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(myFriendCodeProvider);

    return code.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: AppLoadingIndicator()),
      ),
      // Hors ligne, le code n'est pas connu : la feuille reste utilisable
      // (e-mail, saisie de code), seule cette carte s'excuse.
      //
      // Elle s'excusait en promettant que le code « arriverait avec la
      // connexion » — ce qui était faux. `myFriendCodeProvider` n'est pas
      // auto-disposé (un code est attribué à vie, il ne doit pas changer sous
      // la feuille) : l'échec restait donc mémoïsé pour TOUTE la session, et
      // rien ne le rejouait, ni le retour du réseau, ni la fermeture puis la
      // réouverture de la feuille. Le texte dit maintenant ce qui est vrai,
      // et le geste qu'il annonce existe.
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        // `button: true` sans libellé concurrent : la phrase affichée EST le
        // libellé, et elle dit déjà quoi faire. Un libellé posé par-dessus
        // aurait masqué la cause de l'échec aux lecteurs d'écran.
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: () => ref.invalidate(myFriendCodeProvider),
            borderRadius: AppRadius.mdAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                'Ton code n’a pas pu être chargé. Touche pour réessayer.',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
      data: (value) => Row(
        children: [
          Semantics(
            label: 'QR de mon code ami',
            container: true,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.neutral0,
                borderRadius: AppRadius.mdAll,
              ),
              child: QrImageView(
                data: friendCodeQrPayload(value),
                size: _qrSide,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.darkBackground,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.darkBackground,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MON CODE',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  formatFriendCode(value),
                  style: AppTypography.metricM.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Fais-le scanner, ou dicte-le : il ne changera jamais.',
                  style: AppTypography.label.copyWith(
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

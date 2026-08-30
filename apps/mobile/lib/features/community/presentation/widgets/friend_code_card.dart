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
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          'Ton code arrivera avec la connexion.',
          style:
              AppTypography.label.copyWith(color: AppColors.darkTextSecondary),
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
                color: Colors.white,
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
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  formatFriendCode(value),
                  style: AppTypography.metricM
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Fais-le scanner, ou dicte-le : il ne changera jamais.',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

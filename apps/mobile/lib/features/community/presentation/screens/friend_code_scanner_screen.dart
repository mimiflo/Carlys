import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/code_scanner_view.dart';
import '../../domain/friend_code.dart';

/// Scanner du QR d'un ami — rend le code (forme canonique) ou `null`.
///
/// Seul écran de la fonctionnalité à toucher du natif (caméra) : tout le
/// reste — saisie, e-mail, QR affiché — vit sans lui, si bien qu'une caméra
/// refusée n'enlève que le scan. Autorisation et cycle de vie de la caméra :
/// [CodeScannerView].
class FriendCodeScannerScreen extends StatelessWidget {
  const FriendCodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le fond de la barre est celui de la page, que le thème donne : noir
      // pur sous l'OLED.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: AppColors.darkTextPrimary),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scanner un code ami',
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
      // Les QR étrangers (menu de restaurant compris) sont ignorés sans
      // bruit : seul un code Carlys est accepté.
      body: CodeScannerView(
        formats: const [BarcodeFormat.qrCode],
        accept: normalizeFriendCode,
        onCode: (code) => Navigator.of(context).pop(code),
        icon: AppIcons.qrScan,
        hint: 'Vise le QR du profil de ton ami.',
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/friend_code.dart';

/// Scanner du QR d'un ami — rend le code (forme canonique) ou `null`.
///
/// Seul écran de la fonctionnalité à toucher du natif (caméra) : tout le
/// reste — saisie, e-mail, QR affiché — vit sans lui, si bien qu'une caméra
/// refusée n'enlève que le scan.
class FriendCodeScannerScreen extends StatefulWidget {
  const FriendCodeScannerScreen({super.key});

  @override
  State<FriendCodeScannerScreen> createState() =>
      _FriendCodeScannerScreenState();
}

class _FriendCodeScannerScreenState extends State<FriendCodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// La caméra détecte en rafale : seul le PREMIER code Carlys compte, les
  /// QR étrangers (menu de restaurant compris) sont ignorés sans bruit.
  void _onDetect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final code = normalizeFriendCode(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
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
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              // Caméra refusée ou indisponible : un état d'erreur du design
              // system, pas un écran noir muet.
              errorBuilder: (context, error, child) => AppErrorState(
                title: 'Caméra indisponible',
                message:
                    'Autorise-la dans les réglages du téléphone, '
                    'ou tape le code à la main.',
                onRetry: () => _controller.start(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Text(
              'Vise le QR du profil de ton ami.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

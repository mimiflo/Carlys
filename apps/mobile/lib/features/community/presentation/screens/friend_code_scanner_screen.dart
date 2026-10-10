import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/friend_code.dart';

/// Scanner du QR d'un ami — rend le code (forme canonique) ou `null`.
///
/// Seul écran de la fonctionnalité à toucher du natif (caméra) : tout le
/// reste — saisie, e-mail, QR affiché — vit sans lui, si bien qu'une caméra
/// refusée n'enlève que le scan.
///
/// L'autorisation est demandée par `mobile_scanner` au premier démarrage de
/// la caméra, à l'ouverture de l'écran. Depuis la 7, l'écran qui fournit son
/// contrôleur gère aussi le CYCLE DE VIE : caméra coupée quand l'appli passe
/// en arrière-plan, relancée au retour — c'est ce qui la fait repartir quand
/// on revient des réglages après y avoir autorisé la caméra.
class FriendCodeScannerScreen extends StatefulWidget {
  const FriendCodeScannerScreen({super.key});

  @override
  State<FriendCodeScannerScreen> createState() =>
      _FriendCodeScannerScreenState();
}

class _FriendCodeScannerScreenState extends State<FriendCodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  /// L'appli a vraiment quitté l'écran (réglages, autre appli). La boîte
  /// d'autorisation, elle, ne la rend qu'« inactive » : relancer à chaque
  /// retour redemanderait l'autorisation en boucle après un refus.
  bool _away = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _away = true;
        unawaited(_controller.stop());
      case AppLifecycleState.resumed:
        // Encore en démarrage (« Réessayer » puis « Autoriser » : la réponse
        // arrive avant le retour) : un second `start` lèverait une erreur.
        if (_controller.value.isStarting) return;
        if (_away || _controller.value.hasCameraPermission) {
          _away = false;
          unawaited(_controller.start());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
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
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              // Caméra refusée ou indisponible : un état d'erreur du design
              // system, pas un écran noir muet.
              // Pendant l'ouverture, une phrase plutôt qu'un écran noir : si
              // la caméra ne vient jamais, on sait au moins où l'on en est.
              placeholderBuilder: (context) =>
                  const AppLoadingIndicator(label: 'Ouverture de la caméra…'),
              errorBuilder: (context, error) => AppErrorState(
                icon: AppIcons.qrScan,
                title:
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Caméra non autorisée'
                    : 'Caméra indisponible',
                message:
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Autorise l’appareil photo pour Carlys dans les '
                          'réglages du téléphone, ou tape le code à la main.'
                    : 'Elle est peut-être utilisée par une autre appli. '
                          'Réessaie, ou tape le code à la main.',
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

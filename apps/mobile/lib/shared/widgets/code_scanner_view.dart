import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../design_system/design_system.dart';

/// La caméra d'un écran de scan (code ami, code-barres d'un produit) : elle
/// lit les [formats] demandés et rend, UNE fois, le premier code qu'[accept]
/// reconnaît.
///
/// L'autorisation est demandée par `mobile_scanner` au premier démarrage de
/// la caméra, à l'ouverture de l'écran. Depuis la 7, le widget qui fournit
/// son contrôleur gère aussi le CYCLE DE VIE : caméra coupée quand l'appli
/// passe en arrière-plan, relancée au retour — c'est ce qui la fait repartir
/// quand on revient des réglages après y avoir autorisé la caméra. Une
/// caméra refusée n'enlève que le scan : chaque écran offre la saisie.
class CodeScannerView extends StatefulWidget {
  const CodeScannerView({
    required this.formats,
    required this.accept,
    required this.onCode,
    required this.icon,
    required this.hint,
    this.overlay,
    super.key,
  });

  final List<BarcodeFormat> formats;

  /// Le code lu, sous sa forme canonique, ou `null` s'il ne compte pas (un
  /// QR étranger, un chiffre de contrôle faux) : la caméra continue.
  final String? Function(String raw) accept;

  /// Appelé une seule fois, avec le premier code accepté.
  final ValueChanged<String> onCode;

  /// L'icône de l'état d'erreur : celle du geste de l'écran.
  final IconData icon;

  /// Ce qu'il faut viser, sous l'image — et seulement quand la caméra
  /// tourne : sous « Caméra non autorisée », il ne dirait rien de vrai.
  final String hint;

  /// Posé sur l'image de la caméra (un cadre de visée), et seulement quand
  /// elle tourne : jamais sur l'état d'erreur.
  final Widget? overlay;

  @override
  State<CodeScannerView> createState() => _CodeScannerViewState();
}

class _CodeScannerViewState extends State<CodeScannerView>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    formats: widget.formats,
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

  /// La caméra détecte en rafale : seul le PREMIER code accepté compte.
  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = widget.accept(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        widget.onCode(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _scanner()),
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, state, _) => state.error != null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Text(
                    widget.hint,
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _scanner() {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      overlayBuilder: widget.overlay == null
          ? null
          : (context, constraints) => widget.overlay!,
      // Pendant l'ouverture, une phrase plutôt qu'un écran noir : si la
      // caméra ne vient jamais, on sait au moins où l'on en est.
      placeholderBuilder: (context) =>
          const AppLoadingIndicator(label: 'Ouverture de la caméra…'),
      // Caméra refusée ou indisponible : un état d'erreur du design system,
      // pas un écran noir muet.
      errorBuilder: (context, error) {
        final denied =
            error.errorCode == MobileScannerErrorCode.permissionDenied;
        return AppErrorState(
          icon: widget.icon,
          title: denied ? 'Caméra non autorisée' : 'Caméra indisponible',
          message: denied
              ? 'Autorise l’appareil photo pour Carlys dans les réglages du '
                    'téléphone, ou tape le code à la main.'
              : 'Elle est peut-être utilisée par une autre appli. Réessaie, '
                    'ou tape le code à la main.',
          onRetry: () => _controller.start(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/barcode.dart';

/// Le scanner du code-barres d'un produit — rend les chiffres lus, ou
/// `null`. La caméra refusée n'enlève que le scan : le code se tape aussi.
class FoodBarcodeScannerScreen extends StatefulWidget {
  const FoodBarcodeScannerScreen({super.key});

  @override
  State<FoodBarcodeScannerScreen> createState() =>
      _FoodBarcodeScannerScreenState();
}

class _FoodBarcodeScannerScreenState extends State<FoodBarcodeScannerScreen> {
  // Les codes des emballages vendus en France (EAN) et en Amérique (UPC-A).
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
    ],
  );
  bool _done = false;

  /// La saisie au clavier est ouverte : la caméra ne la court-circuite pas.
  bool _typing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// La caméra détecte en rafale : seul le premier code lu compte.
  void _onDetect(BarcodeCapture capture) {
    if (_done || _typing) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      // Une lecture au chiffre de contrôle faux est ignorée : la caméra
      // relit l'image suivante, plus nette.
      if (code != null && isProductBarcode(code)) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  Future<void> _typeCode() async {
    final navigator = Navigator.of(context);
    setState(() => _typing = true);
    final code = await showAppPrompt(
      context,
      title: 'Code-barres',
      message: 'Les chiffres sous les barres : 8, 12 ou 13 en général.',
      icon: AppIcons.typeCode,
      maxLength: 14,
      keyboardType: TextInputType.number,
      confirmLabel: 'Chercher',
      validator: (value) => isProductBarcode(value)
          ? null
          : 'Ce code ne se lit pas : vérifie ses chiffres.',
    );
    if (!mounted) return;
    setState(() => _typing = false);
    if (code == null || _done) return;
    _done = true;
    navigator.pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: AppColors.darkTextPrimary),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scanner un aliment',
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => AppErrorState(
                    title: 'Caméra indisponible',
                    message:
                        'Autorise-la dans les réglages du téléphone, '
                        'ou tape le code à la main.',
                    onRetry: () => _controller.start(),
                  ),
                ),
                // Le cadre de visée : où poser le code-barres. Il ne prend
                // aucun toucher, la caméra lit toute l'image.
                const IgnorePointer(child: Center(child: _Viewfinder())),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Vise le code-barres de l’emballage.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Taper le code',
                  icon: AppIcons.typeCode,
                  variant: AppButtonVariant.secondary,
                  onPressed: _typeCode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le cadre où viser : un rectangle de code-barres au filet violet clair.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  static const double _width = 260;
  static const double _height = 150;
  static const double _stroke = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.cardSecondary),
        border: Border.all(color: AppColors.primaryLight, width: _stroke),
      ),
    );
  }
}

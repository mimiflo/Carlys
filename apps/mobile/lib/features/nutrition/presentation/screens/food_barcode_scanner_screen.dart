import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/code_scanner_view.dart';
import '../../domain/barcode.dart';

/// Le scanner du code-barres d'un produit — rend les chiffres lus, ou
/// `null`. La caméra refusée n'enlève que le scan : le code se tape aussi.
/// Autorisation et cycle de vie de la caméra : [CodeScannerView].
class FoodBarcodeScannerScreen extends StatefulWidget {
  const FoodBarcodeScannerScreen({super.key});

  @override
  State<FoodBarcodeScannerScreen> createState() =>
      _FoodBarcodeScannerScreenState();
}

class _FoodBarcodeScannerScreenState extends State<FoodBarcodeScannerScreen> {
  // Les codes des emballages vendus en France (EAN) et en Amérique (UPC-A).
  static const _formats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
  ];

  bool _done = false;

  /// La saisie au clavier est ouverte : la caméra ne la court-circuite pas.
  bool _typing = false;

  /// Une lecture au chiffre de contrôle faux est ignorée : la caméra relit
  /// l'image suivante, plus nette.
  String? _accept(String raw) {
    final code = raw.trim();
    return !_typing && isProductBarcode(code) ? code : null;
  }

  void _finish(String code) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  Future<void> _typeCode() async {
    setState(() => _typing = true);
    final code = await showAppPrompt(
      context,
      title: 'Code-barres',
      message: 'Les chiffres sous les barres : 8, 12 ou 13 en général.',
      icon: AppIcons.typeCode,
      maxLength: 14,
      keyboardType: TextInputType.number,
      confirmLabel: 'Chercher',
      validator: (value) => isProductBarcode(value.trim())
          ? null
          : 'Ce code ne se lit pas : vérifie ses chiffres.',
    );
    if (!mounted) return;
    setState(() => _typing = false);
    if (code != null) _finish(code.trim());
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
          'Scanner un code-barres',
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CodeScannerView(
              formats: _formats,
              accept: _accept,
              onCode: _finish,
              icon: AppIcons.scanBarcode,
              hint: 'Vise le code-barres de l’emballage.',
              // Le cadre de visée : où poser le code-barres. Il ne prend
              // aucun toucher, la caméra lit toute l'image.
              overlay: const IgnorePointer(child: Center(child: _Viewfinder())),
            ),
          ),
          // Toujours là, caméra refusée comprise : le code se tape aussi.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.gutter,
            ),
            child: AppButton(
              label: 'Taper le code',
              icon: AppIcons.typeCode,
              variant: AppButtonVariant.secondary,
              onPressed: _typeCode,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le cadre où viser : un rectangle de code-barres au filet d'accent — le
/// violet montre où agir, il ne peint pas l'écran.
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

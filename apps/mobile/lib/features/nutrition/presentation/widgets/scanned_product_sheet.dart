import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../providers/packaged_food_provider.dart';
import 'scanned_product_form.dart';

/// La feuille d'un code-barres scanné : le produit se cherche (par l'API),
/// puis se dose et s'ajoute ; inconnu, la saisie à la main prend le relais.
class ScannedProductSheet extends ConsumerWidget {
  const ScannedProductSheet({
    required this.barcode,
    required this.day,
    super.key,
  });

  final String barcode;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(packagedFoodProvider(barcode));
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        // Le clavier, la feuille le laisse déjà de côté (`showAppSheet`).
        AppSpacing.gutter,
      ),
      child: product.when(
        loading: () => const AppLoadingIndicator(label: 'Recherche du produit'),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConnectionAwareError(
              error: error,
              title: 'Produit introuvable pour l’instant',
              message: 'La base des produits n’a pas répondu. Réessaie.',
              offlineMessage:
                  'Le produit se cherche en ligne : il revient avec le réseau.',
              onRetry: () => ref.invalidate(packagedFoodProvider(barcode)),
            ),
            // La base en panne n'empêche pas de manger : la saisie reste.
            AppButton(
              label: 'Saisir à la main',
              variant: AppButtonVariant.ghost,
              onPressed: () => _typeByHand(context),
            ),
          ],
        ),
        data: (result) => result == null
            ? AppEmptyState(
                icon: AppIcons.scanBarcode,
                title: 'Produit inconnu',
                message:
                    'Open Food Facts ne connaît pas ce code-barres, ou pas '
                    'ses calories. Saisis le repas à la main.',
                actionLabel: 'Saisir à la main',
                onAction: () => _typeByHand(context),
              )
            : ScannedProductForm(result: result, day: day),
      ),
    );
  }

  /// La feuille se ferme et l'écran de repas s'ouvre, daté du même jour.
  void _typeByHand(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoutes.newMeal(day: day));
  }
}

/// Le geste entier : la caméra (ou le code tapé), puis la feuille du
/// produit. Rien ne part si le scan est abandonné.
Future<void> scanFood(BuildContext context, DateTime day) async {
  final code = await GoRouter.of(context).push<String>(AppRoutes.scanFood);
  if (code == null || !context.mounted) return;
  await showAppSheet<bool>(
    context,
    builder: (_) => ScannedProductSheet(barcode: code, day: day),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../controllers/meal_scan_controller.dart';
import '../providers/meal_scan_seed.dart';
import '../widgets/meal_editor/meal_photo_flow.dart';
import '../widgets/meal_scan_views.dart';

/// Scanner une assiette : la photo, son analyse par le modèle de vision,
/// puis l'écran du repas pré-rempli — que la personne vérifie avant
/// d'enregistrer. L'IA reconnaît les aliments et estime leurs grammes ; la
/// base CIQUAL en donne les valeurs.
class MealScanScreen extends ConsumerWidget {
  const MealScanScreen({this.day, super.key});

  /// Le jour du journal : le repas y est daté.
  final DateTime? day;

  Future<void> _scan(
    BuildContext context,
    WidgetRef ref,
    MealPhotoSource source,
  ) async {
    final notices = AppNotices.of(context);
    final router = GoRouter.of(context);
    final MealScanSeed? seed;
    try {
      seed = await ref.read(mealScanControllerProvider.notifier).scan(source);
    } on MealPhotoException catch (error) {
      notices.show(
        mealPhotoFailureMessage(error.failure, source),
        tone: AppNoticeTone.error,
      );
      return;
    }
    if (seed == null || !context.mounted) return;
    ref.read(pendingMealScanProvider.notifier).state = seed;
    final missed = [
      for (final item in seed.items)
        if (item.food == null) item.seen,
    ];
    notices.show(
      missed.isEmpty
          ? 'Repas reconnu : vérifie les aliments et leurs grammes.'
          : 'Repas reconnu. Pas dans la base : ${missed.join(', ')}. '
                'Ajoute-les à la main.',
    );
    unawaited(router.pushReplacement(AppRoutes.newMeal(day: day)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(mealScanControllerProvider);
    final padding = MediaQuery.paddingOf(context);
    // L'analyse en cours n'empêche pas de partir : rien ne s'enregistre
    // sans la personne.
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          padding.top + AppSpacing.md,
          AppSpacing.md,
          padding.bottom + AppSpacing.gapSection,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppScreenHeader(
              title: 'Scanner mon assiette',
              tagline: 'L’IA reconnaît, la base calcule',
            ),
            const SizedBox(height: AppSpacing.lg),
            switch (view.phase) {
              MealScanPhase.choosing => MealScanIntro(
                onCamera: () => _scan(context, ref, MealPhotoSource.camera),
                onGallery: () => _scan(context, ref, MealPhotoSource.gallery),
              ),
              MealScanPhase.preparing => const AppLoadingIndicator(
                label: 'Préparation de la photo',
              ),
              MealScanPhase.analyzing => MealScanProgress(
                photo: view.photo,
                since: view.since ?? DateTime.now(),
              ),
              MealScanPhase.failed => MealScanFailure(
                photo: view.photo,
                message: view.error ?? '',
                onRetry: ref.read(mealScanControllerProvider.notifier).retry,
                onByHand: () =>
                    context.pushReplacement(AppRoutes.newMeal(day: day)),
              ),
            },
          ],
        ),
      ),
    );
  }
}

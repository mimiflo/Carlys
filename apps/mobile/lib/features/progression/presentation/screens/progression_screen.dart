import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../domain/progression.dart';
import '../controllers/progression_controllers.dart';
import '../controllers/reward_controllers.dart';
import '../widgets/first_steps_body.dart';
import '../widgets/progression_body.dart';

/// PROFIL DE PROGRESSION : un atelier, pas un jeu.
///
/// Il montre ce que le travail a déposé — un titre porté, des récompenses
/// gagnées, cinq axes qui mesurent la pratique. L'écran ne calcule rien :
/// tout vient du moteur, qui est une fonction pure de faits locaux.
///
/// Il a DEUX visages, et c'est la seule décision qu'il prend : sans aucune
/// récompense au journal, il rend l'atelier du premier jour, plus court d'une
/// moitié. Un compte neuf ne doit jamais voir une vitrine vide.
class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  /// Retrait haut : aucun contenu sous la Dynamic Island.
  static const double _topInset = AppSpacing.gapSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(progressionProfileProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(),
            ),
            const SizedBox(height: _topInset),
            if (ref.watch(progressionUnreadableProvider))
              AppErrorState(
                icon: AppIcons.retry,
                title: 'Ton historique n’a pas pu être lu',
                message: 'Ta progression se recalcule depuis tes séances : '
                    'elle réapparaîtra entière dès que la lecture repart. '
                    'Rien n’est perdu.',
                onRetry: () => ref.invalidate(workoutHistoryProvider),
              )
            else if (profile == null)
              const AppLoadingIndicator(label: 'Lecture de ton historique')
            else if (_isFirstDay(ref, profile))
              FirstStepsBody(
                profile: profile,
                initial: ref.watch(progressionInitialProvider),
              )
            else
              ProgressionBody(
                profile: profile,
                initial: ref.watch(progressionInitialProvider),
              ),
          ],
        ),
      ),
    );
  }

  /// L'atelier ouvre-t-il aujourd'hui ?
  ///
  /// Les DEUX conditions comptent. Sans récompense, on n'a rien à montrer ;
  /// mais un compte qui s'est arrêté trois mois retombe à zéro point tout en
  /// gardant son journal, et lui servir l'écran du premier jour effacerait
  /// son histoire. Le total seul, à l'inverse, ferait clignoter l'écran le
  /// temps que le journal se lise.
  static bool _isFirstDay(WidgetRef ref, ProgressionProfile profile) =>
      profile.points == 0 && ref.watch(showcaseRewardsProvider).isEmpty;
}

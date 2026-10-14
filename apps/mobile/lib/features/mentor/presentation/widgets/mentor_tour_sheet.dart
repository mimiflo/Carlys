import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/mentor_tour.dart';
import '../providers/mentor_providers.dart';
import 'mentor_speak_button.dart';
import 'mentor_tour_card.dart';
import 'mentor_tour_chemin.dart';

/// Où chaque étape emmène. La table vit ICI, pas dans le manifeste : le
/// domaine ne connaît pas le routeur, et un test vérifie que chaque étape a
/// sa destination.
const Map<String, String> mentorTourRoutes = {
  'accueil': AppRoutes.home,
  'entrainement': AppRoutes.training,
  'nutrition': AppRoutes.nutrition,
  'progres': AppRoutes.progress,
  'academy': AppRoutes.academy,
  'communaute': AppRoutes.community,
  'coach': AppRoutes.coach,
};

/// Feuille de la visite guidée (maquette d'octobre 2026) : UNE étape à la
/// fois, l'ordre du manifeste, le chemin des sept pièces sous les yeux, la
/// scène illustrée de la pièce, et deux gestes — y aller (l'ancrage réel),
/// ou passer à la suivante. Rien n'est verrouillé : fermer la feuille
/// n'engage à rien, et « déjà vu » se rejoue depuis les réglages du Mentor.
Future<void> showMentorTourSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorTourSheet());
}

class _MentorTourSheet extends ConsumerWidget {
  const _MentorTourSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(mentorTourProgressProvider);
    final vues = ref.watch(mentorTourVuesProvider).valueOrNull ?? const {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHeader(
            title: 'Visite guidée',
            tagline: 'Découvre ton espace',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (progress == null)
            const AppLoadingIndicator()
          else if (progress.terminee)
            _VisiteTerminee(
              onRejouer: () => ref.read(mentorActionsProvider).rejouerVisite(),
            )
          else
            _Etape(progress: progress, vues: vues),
        ],
      ),
    );
  }
}

/// L'avancement : où en est la visite, la jauge, le chemin des pièces.
class _Avancement extends StatelessWidget {
  const _Avancement({
    required this.label,
    required this.part,
    required this.vues,
    this.etapeCourante,
  });

  final String label;
  final double part;
  final Set<String> vues;
  final String? etapeCourante;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTypography.heading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppGauge(progress: part, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        MentorTourChemin(vues: vues, etapeCourante: etapeCourante),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// La phrase discrète sous les gestes.
class _PiedDeFeuille extends StatelessWidget {
  const _PiedDeFeuille(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
      ),
    );
  }
}

/// Une étape : sa position, le chemin, sa scène, ses gestes.
class _Etape extends ConsumerWidget {
  const _Etape({required this.progress, required this.vues});

  final MentorTourProgress progress;
  final Set<String> vues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etape = progress.prochaine!;
    final derniere = progress.vues + 1 == progress.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Avancement(
          label: 'Étape ${progress.vues + 1} sur ${progress.total}',
          part: (progress.vues + 1) / progress.total,
          vues: vues,
          etapeCourante: etape.id,
        ),
        MentorTourCard(
          illustration:
              mentorTourIllustrations[etape.id] ?? mentorTourFinIllustration,
          titre: etape.titre,
          corps: etape.corps,
          action: MentorSpeakButton(
            speechKey: 'mentor.visite.${etape.id}',
            text: '${etape.titre}. ${etape.corps}',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: etape.libelleAller,
          onPressed: () => _fermerPuisAller(
            context,
            mentorTourRoutes[etape.id],
            avant: () =>
                ref.read(mentorActionsProvider).marquerEtapeVue(etape.id),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: derniere ? 'Terminer la visite' : 'Étape suivante',
          variant: AppButtonVariant.secondary,
          onPressed: () =>
              ref.read(mentorActionsProvider).marquerEtapeVue(etape.id),
        ),
        const _PiedDeFeuille('Tu peux reprendre la visite à tout moment.'),
      ],
    );
  }
}

/// « Aller voir » est l'ancrage réel : [avant] s'exécute (l'étape se marque
/// vue), la feuille se ferme, et la navigation emmène sur la pièce.
///
/// La garde porte sur la route de LA feuille (le navigateur racine est
/// toujours « monté ») : si elle a été balayée ou déjà fermée pendant
/// l'écriture, on ne pop rien et on ne navigue pas — naviguer depuis une
/// feuille disparue surprendrait. Et « y aller » va TOUJOURS, accueil
/// compris : la feuille s'ouvre aussi depuis les réglages du Mentor.
Future<void> _fermerPuisAller(
  BuildContext context,
  String? destination, {
  Future<void> Function()? avant,
}) async {
  final route = ModalRoute.of(context);
  final navigator = Navigator.of(context);
  final router = GoRouter.of(context);
  await avant?.call();
  if (!context.mounted || !(route?.isCurrent ?? false)) {
    return;
  }
  navigator.pop();
  if (destination != null) {
    router.go(destination);
  }
}

/// La fin de la visite : le chemin complet, le sommet atteint, et deux
/// portes — revenir à l'accueil, ou revoir la visite.
class _VisiteTerminee extends StatelessWidget {
  const _VisiteTerminee({required this.onRejouer});

  final VoidCallback onRejouer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Avancement(
          label: '${mentorTour.length} espaces découverts',
          part: 1,
          vues: {for (final step in mentorTour) step.id},
        ),
        const MentorTourCard(
          illustration: mentorTourFinIllustration,
          titre: 'Visite terminée',
          corps:
              'Tu as fait le tour de Carlys. Tout reste à portée de main, et '
              'tu peux revoir la visite quand tu veux.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Revenir à l’accueil',
          onPressed: () => _fermerPuisAller(context, AppRoutes.home),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Revoir la visite',
          variant: AppButtonVariant.secondary,
          onPressed: onRejouer,
        ),
        const _PiedDeFeuille('Retrouve la visite dans les réglages du Mentor.'),
      ],
    );
  }
}

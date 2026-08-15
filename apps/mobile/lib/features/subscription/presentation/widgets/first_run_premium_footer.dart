import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../onboarding/presentation/controllers/first_run_controller.dart';
import 'subscription_purchase_note.dart';

/// Temps d'arrêt du parcours de première ouverture, en bas de l'écran
/// d'abonnement : Premium est proposé franchement, et le refus mène à une
/// proposition explicite de version gratuite — jamais à une impasse.
///
/// Aucun tarif ni offre chiffrée : l'insistance passe par le discours, les
/// avantages affichés au-dessus sont les droits réels du serveur.
class FirstRunPremiumFooter extends ConsumerStatefulWidget {
  const FirstRunPremiumFooter({super.key});

  @override
  ConsumerState<FirstRunPremiumFooter> createState() =>
      _FirstRunPremiumFooterState();
}

enum _Stage { pitch, howTo, freeFallback }

class _FirstRunPremiumFooterState extends ConsumerState<FirstRunPremiumFooter> {
  _Stage _stage = _Stage.pitch;
  bool _finishing = false;

  void _goTo(_Stage stage) => setState(() => _stage = stage);

  /// Repli gratuit accepté : le parcours est terminé une fois pour toutes,
  /// puis l'application s'ouvre.
  ///
  /// Le routeur est saisi AVANT l'attente, et non `context` après. Terminer
  /// le parcours fait disparaître ce pied de page : l'écran d'abonnement
  /// observe l'étape et rebascule aussitôt sur sa version refermable. Sur un
  /// téléphone, cette frame est dessinée bien avant que l'écriture des
  /// préférences ne rende la main — l'état est alors démonté, un `if
  /// (mounted)` échoue et la navigation est perdue : l'utilisateur reste
  /// bloqué sur l'écran d'abonnement, sans plus aucune sortie. Le routeur,
  /// lui, vit avec le conteneur de providers, pas avec ce widget.
  ///
  /// Les étapes précédentes n'ont pas ce problème : leur redirection est
  /// imposée par le tunnel (`_firstRunRedirect`), qui déplace l'utilisateur
  /// tout seul. `done` est la seule étape terminale, donc sans destination
  /// imposée : ici, la navigation doit vraiment aboutir.
  Future<void> _continueForFree() async {
    setState(() => _finishing = true);
    final router = GoRouter.of(context);
    await ref.read(firstRunControllerProvider.notifier).completeJourney();
    router.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_stage) {
          _Stage.pitch => _pitch(),
          _Stage.howTo => _howTo(),
          _Stage.freeFallback => _freeFallback(),
        },
      ),
    );
  }

  List<Widget> _pitch() => [
        const _Title('Commence avec Premium.'),
        const _Paragraph(
          'Tous les droits verrouillés ci-dessus s’ouvrent d’un coup. '
          'Sans Premium, une partie de Carlys reste fermée.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Passer à Premium',
          onPressed: () => _goTo(_Stage.howTo),
          isExpanded: true,
        ),
        TextButton(
          onPressed: () => _goTo(_Stage.freeFallback),
          child: const Text('Continuer sans Premium'),
        ),
      ];

  List<Widget> _howTo() => [
        const _Title('Où activer Premium'),
        const SubscriptionPurchaseNote(),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'J’ai compris',
          variant: AppButtonVariant.secondary,
          onPressed: () => _goTo(_Stage.pitch),
          isExpanded: true,
        ),
      ];

  List<Widget> _freeFallback() => [
        const _Title('Continuer en version gratuite ?'),
        const _Paragraph(
          'Tu gardes les séances, le catalogue et le suivi de base. Les '
          'droits verrouillés le restent, et Premium t’attend à tout moment '
          'depuis ton profil.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Continuer en version gratuite',
          onPressed: _continueForFree,
          isLoading: _finishing,
          isExpanded: true,
        ),
        TextButton(
          onPressed: _finishing ? null : () => _goTo(_Stage.pitch),
          child: const Text('Revenir à Premium'),
        ),
      ];
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Semantics(
        header: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTypography.body.copyWith(
        fontSize: 14,
        height: 1.5,
        color: AppColors.darkTextSecondary,
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/subscription_resume_refresh.dart';

/// Écoute le retour au premier plan tant que l'écran d'abonnement est
/// affiché, et fait relire le plan et les droits.
///
/// Posé sur l'ÉCRAN et non sur la coquille des onglets : le parcours de
/// première ouverture montre l'abonnement hors coquille, et c'est là aussi
/// que l'on paie. La relance différée, elle, vit dans le contrôleur : fermer
/// l'écran avant qu'elle ne parte ne l'annule pas.
class SubscriptionResumeListener extends ConsumerStatefulWidget {
  const SubscriptionResumeListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SubscriptionResumeListener> createState() =>
      _SubscriptionResumeListenerState();
}

class _SubscriptionResumeListenerState
    extends ConsumerState<SubscriptionResumeListener> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(subscriptionResumeRefreshProvider).onResume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

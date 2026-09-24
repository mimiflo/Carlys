import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/design_system.dart';
import '../../data/services/firebase_push_messenger.dart';
import '../../domain/entities/push_destination.dart';
import '../../domain/services/push_messenger.dart';

/// Le guichet des notifications, côté application.
///
/// Deux rôles, qu'aucun autre endroit ne tient :
///  - AFFICHER celles reçues pendant que l'application est ouverte : le
///    système ne le fait pas lui-même, et sans ce guichet un encouragement
///    envoyé au moment précis où l'on utilise Carlys n'existe pas. Elle ne la
///    fabrique jamais : le contenu vient du serveur ;
///  - OUVRIR l'écran qu'annonce une notification touchée, que ce toucher
///    ait réveillé l'application ou l'ait lancée. Sans ça, toucher « Léa
///    t'invite à un défi » ouvrait l'accueil, et le défi restait à chercher.
///
/// Posé au-dessus de la coquille, il vaut pour tous les onglets.
class PushForegroundHost extends ConsumerStatefulWidget {
  const PushForegroundHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushForegroundHost> createState() => _PushForegroundHostState();
}

class _PushForegroundHostState extends ConsumerState<PushForegroundHost> {
  static const _logger = AppLogger('PushForegroundHost');

  StreamSubscription<PushNotice>? _received;
  StreamSubscription<PushDestination>? _opened;

  @override
  void initState() {
    super.initState();
    final messenger = ref.read(pushMessengerProvider);
    _received = messenger.onForegroundMessage.listen(_show);
    _opened = messenger.onNotificationOpened.listen(_open);
    unawaited(_openLaunchDestination(messenger));
  }

  @override
  void dispose() {
    unawaited(_received?.cancel());
    unawaited(_opened?.cancel());
    super.dispose();
  }

  /// La notification dont le toucher a LANCÉ l'application. Le SDK ne la
  /// rend qu'une fois : recréer la coquille (déconnexion puis reconnexion)
  /// ne rouvre pas le même écran.
  Future<void> _openLaunchDestination(PushMessenger messenger) async {
    final options = ref.read(appEnvironmentProvider).push;
    // Sans configuration Firebase (tests, CI), aucune notification n'a pu
    // lancer l'application : rien à demander au SDK.
    if (options == null) return;
    try {
      final destination = await messenger.takeLaunchDestination(options);
      if (destination != null) _open(destination);
    } on Exception catch (error) {
      // L'application s'ouvre alors là où elle s'ouvre toujours : le
      // lancement ne dépend jamais de ce détour.
      _logger.warning('Notification de lancement illisible', error: error);
    }
  }

  void _open(PushDestination destination) {
    if (!mounted) return;
    GoRouter.of(context).go(AppRoutes.pushDestination(destination));
  }

  void _show(PushNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final destination = notice.destination;
    // Le bandeau se peint en surface INVERSE (claire sur l'appli sombre) :
    // ses textes prennent la couleur qui va avec. Peints en texte clair du
    // thème sombre, le titre disparaissait sur le fond clair.
    final onBanner = Theme.of(context).colorScheme.onInverseSurface;

    // Une seule à la fois : deux encouragements reçus coup sur coup
    // empileraient deux bandeaux devant le contenu.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notice.title,
                style: AppTypography.label.copyWith(
                  color: onBanner,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (notice.body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  notice.body,
                  style: AppTypography.label.copyWith(color: onBanner),
                ),
              ],
            ],
          ),
          // Le même écran que si on avait touché la notification système.
          action: destination == null
              ? null
              : SnackBarAction(
                  label: 'Voir',
                  onPressed: () => _open(destination),
                ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

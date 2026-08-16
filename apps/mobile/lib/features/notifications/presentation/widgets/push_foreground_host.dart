import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../data/services/firebase_push_messenger.dart';
import '../../domain/services/push_messenger.dart';

/// Affiche les notifications reçues PENDANT que l'application est ouverte.
///
/// Le système ne les affiche pas lui-même dans ce cas : sans ce guichet, un
/// encouragement envoyé au moment précis où l'on utilise Carlys n'existe
/// pas. C'est le seul cas où l'application montre une notification, et elle
/// ne la fabrique jamais : le contenu vient du serveur.
///
/// Posé au-dessus de la coquille, il vaut pour tous les onglets.
class PushForegroundHost extends ConsumerStatefulWidget {
  const PushForegroundHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushForegroundHost> createState() => _PushForegroundHostState();
}

class _PushForegroundHostState extends ConsumerState<PushForegroundHost> {
  StreamSubscription<PushNotice>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        ref.read(pushMessengerProvider).onForegroundMessage.listen(_show);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _show(PushNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

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
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (notice.body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  notice.body,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

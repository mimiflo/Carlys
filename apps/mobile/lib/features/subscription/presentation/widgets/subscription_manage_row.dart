import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/subscription_controllers.dart';

/// « Gérer mon abonnement » : la ligne qui ouvre le portail de facturation
/// du prestataire, une fois Premium.
///
/// Moyen de paiement, factures, résiliation : tout se fait LÀ-BAS, et le
/// serveur reflète le résultat par webhook. L'application n'a ni formulaire
/// de carte ni bouton « résilier » à elle : elle ouvre la porte, c'est tout.
/// Au retour, le plan est relu, et une résiliation se lit « Accès jusqu'au ».
class SubscriptionManageRow extends ConsumerStatefulWidget {
  const SubscriptionManageRow({super.key});

  static const String label = 'Gérer mon abonnement';

  @override
  ConsumerState<SubscriptionManageRow> createState() =>
      _SubscriptionManageRowState();
}

class _SubscriptionManageRowState extends ConsumerState<SubscriptionManageRow> {
  /// Indicateur d'attente calé sur l'icône de la ligne (géométrie pure).
  static const double _spinnerSize = 20;

  bool _opening = false;
  PortalOutcome? _outcome;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _outcome = null;
    });
    final outcome = await ref.read(subscriptionActionsProvider).manage();
    if (!mounted) return;
    setState(() {
      _opening = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notice = _noticeFor(_outcome);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Un seul nœud pour les lecteurs d'écran : libellés, état d'attente
        // et action de la ligne fusionnés, sans perdre le « toucher ».
        MergeSemantics(
          child: Semantics(
            button: true,
            enabled: !_opening,
            child: AppListRow(
              leading: AppIcons.settings,
              title: SubscriptionManageRow.label,
              subtitle: 'Paiement, factures, résiliation',
              // Pendant l'ouverture, la ligne attend et ne répond plus :
              // deux appuis n'ouvriraient pas deux portails.
              trailing: _opening
                  ? const AppLoadingIndicator(
                      size: _spinnerSize,
                      label: 'Ouverture du portail',
                    )
                  : null,
              onTap: _opening ? null : _open,
            ),
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _PortalNotice(notice),
        ],
      ],
    );
  }

  /// Ce que la ligne dit quand le portail ne s'est pas ouvert. Rien quand il
  /// s'est ouvert : le navigateur est passé devant.
  static _Notice? _noticeFor(PortalOutcome? outcome) => switch (outcome) {
    null || PortalOpened() => null,
    PortalOffline() => const _Notice(
      icon: AppIcons.offline,
      text:
          'Tu es hors ligne. Le portail a besoin d’une connexion : réessaie '
          'quand le réseau est là.',
    ),
    PortalRefused(:final message) => _Notice(
      icon: AppIcons.info,
      text: message,
    ),
    PortalCannotOpen() => const _Notice(
      icon: AppIcons.error,
      text: 'Aucun navigateur n’a pu s’ouvrir sur cet appareil.',
      isError: true,
    ),
    PortalFailed() => const _Notice(
      icon: AppIcons.error,
      text: 'Le portail n’a pas pu s’ouvrir. Réessaie dans un instant.',
      isError: true,
    ),
  };
}

class _Notice {
  const _Notice({required this.icon, required this.text, this.isError = false});

  final IconData icon;
  final String text;

  /// Vrai pour une panne ; faux pour un état qui n'est pas une faute (hors
  /// ligne, refus expliqué), dit sur le ton d'une précision.
  final bool isError;
}

/// Le message sous la ligne, annoncé aux lecteurs d'écran dès qu'il change.
class _PortalNotice extends StatelessWidget {
  const _PortalNotice(this.notice);

  final _Notice notice;

  /// Taille d'icône de la mention (géométrie pure).
  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final color = notice.isError
        ? Theme.of(context).colorScheme.error
        : AppColors.darkTextSecondary;

    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(notice.icon, size: _iconSize, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              notice.text,
              style: AppTypography.label.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

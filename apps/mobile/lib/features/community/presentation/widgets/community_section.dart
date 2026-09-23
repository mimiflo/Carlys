import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../providers/community_screen_state.dart';

/// Une section titrée, absente si sa liste est vide : pas de titre orphelin.
List<Widget> communitySection(String title, List<Widget>? children) {
  if (children == null || children.isEmpty) {
    return const [];
  }
  return [
    AppSectionLabel(title),
    const SizedBox(height: AppSpacing.xs),
    for (final child in children) ...[
      child,
      const SizedBox(height: AppSpacing.gapRow),
    ],
    const SizedBox(height: AppSpacing.xs),
  ];
}

/// Ce que dit la loupe quand rien ne correspond : un onglet vide sans un
/// mot laisserait croire que la page a cassé.
class CommunityNoMatch extends StatelessWidget {
  const CommunityNoMatch(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        message,
        style: AppTypography.label.copyWith(color: AppColors.darkTextSecondary),
      ),
    );
  }
}

/// L'arbitrage d'un ONGLET : erreur, premier chargement, ou contenu.
///
/// Chaque onglet tranche sur SES sources, et plus sur les sept à la fois :
/// une panne de la ligue ne doit pas masquer les défis, qui ont répondu.
/// Le contenu reste affiché pendant un rafraîchissement (Riverpod garde la
/// valeur précédente) : le remplacer par un indicateur ferait sauter la
/// lecture à chaque écriture.
class CommunityTabGate extends ConsumerWidget {
  const CommunityTabGate({
    required this.sources,
    required this.errorTitle,
    required this.offlineMessage,
    required this.builder,
    super.key,
  });

  final List<AsyncValue<Object?>> sources;
  final String errorTitle;
  final String offlineMessage;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = communityScreenState(sources: sources, porteursDuVide: []);
    final erreur = etat.error;
    if (erreur != null) {
      return ConnectionAwareError(
        error: erreur,
        title: errorTitle,
        offlineMessage: offlineMessage,
        onRetry: () => reloadCommunity(ref),
      );
    }
    if (!sources.any((source) => source.hasValue)) {
      return const AppLoadingIndicator();
    }
    return builder(context);
  }
}

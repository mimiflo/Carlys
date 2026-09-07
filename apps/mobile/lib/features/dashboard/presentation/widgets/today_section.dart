import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../nutrition/presentation/controllers/water_controllers.dart';
import '../controllers/today_metrics.dart';
import 'section_title_bar.dart';
import 'today_grid.dart';
import 'today_primer.dart';

/// « AUJOURD'HUI » : la grille du jour, et les TROIS chemins qui y mènent.
///
/// L'accueil confondait « pas encore de cible » et « pas de réponse » : le
/// `valueOrNull` de l'objectif rend `null` PENDANT le chargement comme EN
/// erreur. Un téléphone hors réseau se voyait donc annoncer qu'il n'avait
/// rien configuré, et l'amorçage l'invitait à refaire ce qui était déjà
/// fait — sur l'écran le plus visité de l'application.
///
/// Les trois cas se distinguent ici : on attend, on n'a pas pu, ou on sait.
/// L'amorçage n'appartient qu'au troisième, et seulement quand le serveur a
/// vraiment répondu « aucune cible ».
///
/// ## Pourquoi l'attente ne montre pas d'indicateur
///
/// `metabolismReportProvider` est `autoDispose` : l'accueil le redemande
/// CHAQUE fois qu'on revient sur l'onglet. Un indicateur circulaire à cette
/// place clignoterait donc à chaque retour, sur l'écran le plus visité de
/// l'application — le remède serait plus voyant que le mal. Tant qu'on ne
/// sait pas, la section se tait : elle n'affirme rien, et c'est tout ce
/// qu'on lui demande. Le tort n'a jamais été de se taire, il a été
/// d'INVITER à remplir un profil déjà rempli.
class TodaySection extends ConsumerWidget {
  const TodaySection({
    required this.onStartPrimer,
    required this.onOpenHydration,
    super.key,
  });

  /// Ouvre le profil métabolique, seul endroit où les cibles se calculent.
  final VoidCallback onStartPrimer;

  final VoidCallback onOpenHydration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(metabolismTargetWaterMlProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) => TitledSection(
            icon: AppIcons.today,
            label: 'Aujourd’hui',
            child: ConnectionAwareError(
              error: error,
              title: 'Objectifs indisponibles',
              message: 'Tes objectifs du jour n’ont pas pu être chargés.',
              offlineMessage:
                  'Tes objectifs du jour se calculent sur le serveur : '
                  'ils reviennent avec le réseau.',
              onRetry: () => ref.invalidate(metabolismReportProvider),
            ),
          ),
          // Le serveur a répondu, et il n'a pas de cible : le profil
          // métabolique n'est pas rempli. Quatre cellules à « — » diraient
          // quatre fois la même absence ; l'amorçage la dit une fois, et
          // porte alors son propre titre.
          data: (targetWaterMl) => targetWaterMl == null
              ? TodayPrimer(onStart: onStartPrimer)
              : TitledSection(
                  icon: AppIcons.today,
                  label: 'Aujourd’hui',
                  child: TodayGrid(
                    metrics: ref.watch(todayMetricsProvider),
                    onOpenHydration: onOpenHydration,
                  ),
                ),
        );
  }
}

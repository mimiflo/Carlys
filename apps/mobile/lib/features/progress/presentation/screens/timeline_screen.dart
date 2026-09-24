import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/timeline_controller.dart';
import '../widgets/timeline_filter_bar.dart';
import '../widgets/timeline_row.dart';

/// LA FRISE : ce qui s'est passé, dans l'ordre, du plus récent au plus ancien.
///
/// Une lecture SERVEUR, jamais l'historique local : celui-ci est plafonné à
/// 60 séances au rapatriement, et une frise tronquée à soixante séances
/// mentirait sur deux ans de pratique. Hors ligne, l'écran le DIT.
///
/// Les en-têtes de mois se posent ici, pas côté serveur : découpées là-bas,
/// une page vaudrait deux lignes ou deux cents selon le mois. Le serveur
/// pagine par compte d'éléments, et cet écran ouvre un en-tête quand le mois
/// change — y compris à cheval sur deux pages.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scroll = ScrollController();

  /// Distance du bas à partir de laquelle la page suivante se demande.
  static const double _seuil = 400;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_surDefilement);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _surDefilement() {
    if (!_scroll.hasClients) {
      return;
    }
    final reste = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (reste < _seuil) {
      // Le contrôleur ignore l'appel s'il n'y a plus rien ou si une page est
      // déjà en route : c'est lui qui tient l'état, pas le défilement.
      ref.read(timelineControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final frise = ref.watch(timelineControllerProvider);

    return AppDarkScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        leading: const AppBackButton(),
        title: Text(
          'Ton histoire',
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: frise.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Chargement de ton histoire'),
          error: (_, __) => AppErrorState(
            title: 'Histoire indisponible',
            message: AppErrorState.retryConnectionMessage,
            onRetry: () => ref.invalidate(timelineControllerProvider),
          ),
          data: _corps,
        ),
      ),
    );
  }

  Widget _corps(TimelineState state) {
    final notifier = ref.read(timelineControllerProvider.notifier);
    final lignes = _avecEnTetes(state.events);

    return Column(
      children: [
        TimelineFilterBar(
          selected: notifier.kinds,
          onChanged: (kinds) => notifier.filter(kinds),
        ),
        Expanded(
          child: lignes.isEmpty
              ? const AppEmptyState(
                  title: 'Ton histoire commence',
                  message:
                      'Termine une séance, note une pesée, réponds à une '
                      'leçon : chaque geste laisse une trace ici.',
                  icon: AppIcons.history,
                )
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.xl,
                  ),
                  itemCount: lignes.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index >= lignes.length) {
                      return _Pied(state: state, onRetry: notifier.loadMore);
                    }
                    return lignes[index];
                  },
                ),
        ),
      ],
    );
  }

  /// Les lignes, avec un en-tête à chaque changement de mois.
  List<Widget> _avecEnTetes(List<ProgressEvent> events) {
    final lignes = <Widget>[];
    String? moisCourant;
    for (final event in events) {
      final local = event.occurredAt.toLocal();
      final mois = '${local.year}-${local.month}';
      if (mois != moisCourant) {
        moisCourant = mois;
        lignes.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xxs,
            ),
            child: AppSectionLabel(formatMonthYearCapitalized(local)),
          ),
        );
      }
      lignes.add(TimelineRow(key: ValueKey(event.id), event: event));
    }
    return lignes;
  }
}

/// Le pied de liste : la page suivante arrive, ou elle a échoué.
class _Pied extends StatelessWidget {
  const _Pied({required this.state, required this.onRetry});

  final TimelineState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.error == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppLoadingIndicator(),
      );
    }
    // La page déjà lue reste à l'écran : perdre deux ans de frise parce que
    // la suite n'est pas venue serait une punition pour un réseau qui
    // flanche.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'La suite n’a pas pu être chargée.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Réessayer',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

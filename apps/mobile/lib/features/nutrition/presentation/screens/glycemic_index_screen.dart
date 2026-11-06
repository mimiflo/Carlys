import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/glycemic_food.dart';
import '../../domain/glycemic_selection.dart';
import '../providers/glycemic_index_providers.dart';
import '../widgets/glycemic/glycemic_filters.dart';
import '../widgets/glycemic/glycemic_food_row.dart';
import '../widgets/glycemic/glycemic_intro_card.dart';
import '../widgets/glycemic/glycemic_source_note.dart';

/// Le tableau des index glycémiques : contenu embarqué, lisible hors ligne,
/// sans aucune API. Une recherche, un filtre par famille, un tri par IG ;
/// l'explication en tête, la source au pied.
class GlycemicIndexScreen extends ConsumerStatefulWidget {
  const GlycemicIndexScreen({super.key});

  @override
  ConsumerState<GlycemicIndexScreen> createState() =>
      _GlycemicIndexScreenState();
}

class _GlycemicIndexScreenState extends ConsumerState<GlycemicIndexScreen> {
  final _search = TextEditingController();
  String _query = '';
  GlycemicCategory? _category;
  GlycemicSort _sort = GlycemicSort.byCategory;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(glycemicIndexPackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Index glycémique')),
      body: pack.when(
        loading: () => const AppLoadingIndicator(label: 'Ouverture du tableau'),
        // Le pack n'est pas `autoDispose` : sans reprise, un échec de lecture
        // resterait mémoïsé jusqu'à la fin de la session.
        error: (error, _) => AppErrorState(
          title: 'Tableau indisponible',
          message: 'Le tableau des index glycémiques n’a pas pu être chargé.',
          onRetry: () => ref.invalidate(glycemicIndexPackProvider),
        ),
        data: (foods) {
          final shown = glycemicFoodsFor(
            foods,
            query: _query,
            category: _category,
            sort: _sort,
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gapRow,
              AppSpacing.gutter,
              MediaQuery.paddingOf(context).bottom + AppSpacing.gapSection,
            ),
            children: [
              const GlycemicIntroCard(),
              const SizedBox(height: AppSpacing.gapSection),
              AppSearchField(
                controller: _search,
                hint: 'Chercher un aliment',
                onChanged: (query) => setState(() => _query = query),
              ),
              const SizedBox(height: AppSpacing.xs),
              GlycemicFilters(
                category: _category,
                onCategory: (category) => setState(() => _category = category),
                sort: _sort,
                onSort: (sort) => setState(() => _sort = sort),
              ),
              const SizedBox(height: AppSpacing.gapRow),
              if (shown.isEmpty)
                AppEmptyState(
                  icon: AppIcons.search,
                  title: 'Aucun aliment trouvé',
                  message:
                      'Le tableau compte ${foods.length} aliments courants. '
                      'Essaie un autre mot, ou une autre famille.',
                )
              else
                ..._rows(shown),
              const SizedBox(height: AppSpacing.gapSection),
              const GlycemicSourceNote(),
            ],
          );
        },
      ),
    );
  }

  /// Par famille et sans filtre, chaque famille a son titre ; triées par
  /// IG, les familles se mêlent et chaque ligne dit la sienne.
  List<Widget> _rows(List<GlycemicFood> shown) {
    final grouped = _sort == GlycemicSort.byCategory && _category == null;
    return [
      for (final (index, food) in shown.indexed) ...[
        if (grouped &&
            (index == 0 || shown[index - 1].category != food.category)) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          Semantics(header: true, child: AppSectionLabel(food.category.title)),
          const SizedBox(height: AppSpacing.xs),
        ],
        GlycemicFoodRow(
          food: food,
          showCategory: _sort != GlycemicSort.byCategory && _category == null,
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    ];
  }
}

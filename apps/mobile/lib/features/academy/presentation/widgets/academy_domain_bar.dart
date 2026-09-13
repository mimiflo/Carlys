import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';

/// Barre de domaines de l'Academy : « Tous », puis les douze domaines.
///
/// POURQUOI une barre et pas de simples sections empilées. Le pack tenait en
/// 22 leçons réparties sur quatre domaines : tout dérouler dans une liste
/// unique se lisait encore. À douze domaines, et à mesure que le contenu
/// s'étoffe, ce déroulé devient un couloir : pour atteindre Calisthenics il
/// faut traverser onze domaines qu'on ne cherchait pas.
///
/// « Tous » reste en tête et par défaut : c'est la lecture de découverte,
/// celle qui donne envie de tomber sur une leçon qu'on n'aurait pas cherchée.
/// Les pastilles servent à VISER, pas à remplacer la flânerie.
class AcademyDomainBar extends StatelessWidget {
  const AcademyDomainBar({
    required this.selected,
    required this.onSelect,
    required this.countOf,
    super.key,
  });

  /// Domaine choisi, `null` pour « Tous ».
  final AcademyCategory? selected;

  final ValueChanged<AcademyCategory?> onSelect;

  /// Nombre de leçons du domaine — un domaine vide ne s'affiche pas.
  final int Function(AcademyCategory) countOf;

  @override
  Widget build(BuildContext context) {
    final domaines = AcademyCategory.values
        .where((category) => countOf(category) > 0)
        .toList();

    return SizedBox(
      height: AppSpacing.touchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Le rembourrage de la page est déjà posé par l'écran ; ici on ne
        // rajoute rien, sinon la première pastille décolle du bord.
        padding: EdgeInsets.zero,
        itemCount: domaines.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Pastille(
              label: 'Tous',
              selected: selected == null,
              onTap: () => onSelect(null),
            );
          }
          final domaine = domaines[index - 1];
          return _Pastille(
            label: domaine.label,
            selected: selected == domaine,
            onTap: () => onSelect(domaine),
          );
        },
      ),
    );
  }
}

/// Une pastille centrée dans la hauteur de la barre.
///
/// `AppPill` se dimensionne à son contenu ; sans ce centrage elle serait
/// étirée sur toute la hauteur de la cible tactile.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppPill(
        label: label,
        selected: selected,
        // Violet et non orange plein : depuis l'unification des boutons, tout
        // ce sur quoi on clique parle la couleur de la marque.
        selectedTone: AppPillTone.primary,
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Amorces de conversation, alignées à droite comme des paroles à venir.
///
/// Elles ne sont **jamais codées en dur** : elles se calculent depuis l'état
/// réel — un modèle de séance disponible, un record récent, un poids qui
/// stagne. Un champ vide invite des questions que le domaine ne sait pas
/// honorer ; ces puces orientent vers ce que le coach sait vraiment faire.
class CoachSuggestions extends StatelessWidget {
  const CoachSuggestions({
    required this.suggestions,
    required this.onSelected,
    super.key,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  /// Hauteur de la bande. Fixe : une liste horizontale n'a pas de hauteur
  /// intrinsèque, et la barre ne doit pas changer de taille d'un état à l'autre.
  static const double _height = 34;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Une ligne qui part de la GAUCHE et défile, plutôt qu'un pavé qui se
    // replie : les puces se lisent dans l'ordre où on les a écrites, et une
    // suggestion de plus allonge la bande au lieu de pousser la conversation
    // vers le haut.
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Align(
            child: AppPill(
              label: suggestion,
              tone: AppPillTone.primary,
              onTap: () => onSelected(suggestion),
            ),
          );
        },
      ),
    );
  }
}

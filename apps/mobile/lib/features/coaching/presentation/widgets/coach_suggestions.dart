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

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final suggestion in suggestions)
          AppPill(
            label: suggestion,
            tone: AppPillTone.primary,
            onTap: () => onSelected(suggestion),
          ),
      ],
    );
  }
}

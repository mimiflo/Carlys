import 'package:flutter/material.dart';

import '../icons/app_icons.dart';

/// Champ de recherche standard avec effacement rapide.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.onChanged,
    this.hint = 'Rechercher',
    this.semanticLabel,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final String? semanticLabel;

  /// Le champ prend le focus à l'ouverture : une feuille qui ne sert qu'à
  /// chercher ouvre le clavier d'emblée.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel ?? hint,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(AppIcons.search),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    icon: const Icon(AppIcons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

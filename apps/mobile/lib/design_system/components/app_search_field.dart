import 'package:flutter/material.dart';

import '../icons/app_icons.dart';

/// Champ de recherche standard avec effacement rapide.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.onChanged,
    this.hint = 'Rechercher',
    this.semanticLabel,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel ?? hint,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
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

import 'package:flutter/material.dart';

import '../spacing/app_spacing.dart';

/// Champ de saisie standard Carlys (style via InputDecorationTheme).
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autocorrect = true,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.helper,
    this.inlineLabel = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  /// Saisie en direct — pour un formulaire dont l'état vit dans un contrôleur.
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool autocorrect;
  final IconData? prefixIcon;

  /// Nombre de lignes visibles ; > 1 pour un champ multiligne (notes).
  final int maxLines;

  /// Longueur maximale acceptée — reprend la borne partagée avec l'API.
  final int? maxLength;

  /// Ligne d'aide sous le champ (contrainte, précision), dans le style du
  /// thème — jamais un second libellé.
  final String? helper;

  /// Étiquette DANS le champ (texte fantôme) plutôt qu'au-dessus — le style
  /// des écrans d'entrée. Le libellé reste la référence : il devient le texte
  /// fantôme quand aucun [hint] n'est fourni, et reste annoncé aux lecteurs
  /// d'écran.
  final bool inlineLabel;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autocorrect: autocorrect,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: inlineLabel ? (hint ?? label) : hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );

    if (inlineLabel) {
      return Semantics(label: label, child: field);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        field,
      ],
    );
  }
}

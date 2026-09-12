import 'package:flutter/material.dart';

import '../spacing/app_spacing.dart';

/// Champ mot de passe avec bascule de visibilité accessible.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.label,
    this.controller,
    this.errorText,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    this.prefixIcon,
    this.prefixIconColor,
    this.helper,
    this.inlineLabel = false,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final IconData? prefixIcon;

  /// Couleur de l'icône de préfixe — au thème par défaut ; les écrans
  /// d'entrée passent [AppColors.fieldIcon], le rose clair de leur maquette.
  final Color? prefixIconColor;

  /// Ligne d'aide sous le champ — la contrainte de longueur, typiquement.
  final String? helper;

  /// Étiquette DANS le champ plutôt qu'au-dessus, comme [AppTextField] :
  /// le libellé devient le texte fantôme et reste annoncé aux lecteurs
  /// d'écran.
  final bool inlineLabel;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        hintText: widget.inlineLabel ? widget.label : null,
        helperText: widget.helper,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, color: widget.prefixIconColor),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscured = !_obscured),
          tooltip: _obscured
              ? 'Afficher le mot de passe'
              : 'Masquer le mot de passe',
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );

    if (widget.inlineLabel) {
      return Semantics(label: widget.label, child: field);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        field,
      ],
    );
  }
}

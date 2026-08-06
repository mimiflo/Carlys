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

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        TextFormField(
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
            errorText: widget.errorText,
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
        ),
      ],
    );
  }
}

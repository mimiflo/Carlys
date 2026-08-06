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
    this.onFieldSubmitted,
    this.enabled = true,
    this.autocorrect = true,
    this.prefixIcon,
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
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool autocorrect;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xxs),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          autocorrect: autocorrect,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          ),
        ),
      ],
    );
  }
}

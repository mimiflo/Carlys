import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import 'app_button.dart';
import 'app_dialogs.dart';
import 'app_popup_card.dart';
import 'app_text_field.dart';

/// Demande une saisie COURTE (un nom, un libellé) dans une popup, et la rend.
///
/// Rend le texte saisi, débarrassé de ses espaces de bord ; `null` si la
/// personne renonce, touche le voile ou fait retour. Un texte vide ne se
/// valide pas : le bouton reste éteint tant que le champ l'est.
///
/// [validator] ajoute une règle propre au geste : il rend le message
/// d'erreur à afficher sous le champ, ou `null` si la saisie convient. Le
/// champ prend le focus à l'ouverture, et la popup remonte au-dessus du
/// clavier.
Future<String?> showAppPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? hint,
  String initialValue = '',
  int? maxLength,
  String confirmLabel = 'Valider',
  String cancelLabel = 'Annuler',
  IconData? icon,
  String? Function(String value)? validator,
}) {
  return showAppDialog<String>(
    context,
    builder: (_) => _PromptCard(
      title: title,
      message: message,
      hint: hint,
      initialValue: initialValue,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon ?? AppIcons.promptEdit,
      validator: validator,
    ),
  );
}

class _PromptCard extends StatefulWidget {
  const _PromptCard({
    required this.title,
    required this.message,
    required this.hint,
    required this.initialValue,
    required this.maxLength,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.validator,
  });

  final String title;
  final String? message;
  final String? hint;
  final String initialValue;
  final int? maxLength;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final String? Function(String value)? validator;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  String? _error;

  String get _value => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _value;
    if (value.isEmpty) return;
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppPopupCard(
      icon: widget.icon,
      title: widget.title,
      message: widget.message,
      content: AppTextField(
        // Le titre nomme le champ pour les lecteurs d'écran ; à l'écran, la
        // carte le dit déjà au-dessus : l'indice se loge dans le champ.
        label: widget.title,
        inlineLabel: true,
        hint: widget.hint,
        controller: _controller,
        maxLength: widget.maxLength,
        autofocus: true,
        textInputAction: TextInputAction.done,
        errorText: _error,
        // Chaque frappe réévalue le bouton, et efface une erreur devenue
        // fausse.
        onChanged: (_) => setState(() => _error = null),
        onFieldSubmitted: (_) => _submit(),
      ),
      actions: [
        AppButton(
          label: widget.confirmLabel,
          onPressed: _value.isEmpty ? null : _submit,
        ),
        AppButton(
          label: widget.cancelLabel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

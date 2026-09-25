import 'package:flutter/widgets.dart';

/// Un champ dont le TEXTE vit dans l'état de l'écran, pas dans le champ.
///
/// La saisie remonte à l'état à chaque frappe ; l'état, lui, peut aussi
/// réécrire la case — retirer le dernier aliment d'un repas remplit les
/// cases de ses derniers totaux. Ce widget tient le `TextEditingController`
/// et ne le réécrit que si le texte de l'état DIFFÈRE de celui de la case :
/// une frappe qui revient de l'état ne déplace donc jamais le curseur.
class BoundText extends StatefulWidget {
  const BoundText({required this.text, required this.builder, super.key});

  /// Le texte que l'état donne à la case.
  final String text;
  final Widget Function(TextEditingController controller) builder;

  @override
  State<BoundText> createState() => _BoundTextState();
}

class _BoundTextState extends State<BoundText> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(BoundText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

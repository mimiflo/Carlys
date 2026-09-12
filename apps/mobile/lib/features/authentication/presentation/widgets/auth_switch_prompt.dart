import 'package:flutter/material.dart';

/// La ligne de bascule des écrans d'entrée : une question (« Pas encore de
/// compte ? ») et son action, centrées.
///
/// Widget à part entière, pas un morceau d'écran : son style se résout dans
/// SON contexte, donc SOUS le thème de marque qu'[AuthScaffold] impose.
/// Construit directement dans l'écran, `Theme.of` remontait au thème
/// AMBIANT — et le réglage clair posait un gris sombre (2,79:1) sur le fond
/// sombre imposé.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String prompt;
  final String actionLabel;

  /// `null` neutralise l'action (soumission en cours).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Wrap : passe à la ligne sur les écrans étroits ou avec une grande
    // taille de police système, au lieu de déborder.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.bodySmall),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    );
  }
}

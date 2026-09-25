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
    this.prefixIconColor,
    this.suffixText,
    this.suffixIcon,
    this.suffixIconColor,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.helper,
    this.inlineLabel = false,
    this.autofocus = false,
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

  /// Couleur de l'icône de préfixe — au thème par défaut ; les écrans
  /// d'entrée passent [AppColors.fieldIcon], le rose clair de leur maquette.
  final Color? prefixIconColor;

  /// L'unité écrite DANS le champ, après la saisie (« 320 g ») : elle se lit
  /// avec le nombre, là où un libellé au-dessus se lirait séparément.
  final String? suffixText;

  /// Une icône en fin de champ, qui dit ce que le champ accepte (le crayon
  /// d'un nom qu'on peut changer). Décorative : le champ entier répond déjà
  /// au doigt, elle n'est donc ni un bouton ni annoncée.
  final IconData? suffixIcon;

  /// Couleur de l'icône de fin ; celle du thème par défaut.
  final Color? suffixIconColor;

  /// La valeur se LIT mais ne se modifie pas : une quantité calculée, par
  /// exemple. Contrairement à [enabled] faux, le texte garde sa couleur
  /// pleine (un champ désactivé pâlit, et une valeur qu'on doit lire ne
  /// pâlit pas) ; le lecteur d'écran l'annonce en lecture seule.
  final bool readOnly;

  /// Nombre de lignes visibles ; > 1 pour un champ multiligne (notes).
  final int maxLines;

  /// Avec [maxLines] > 1, le champ NAÎT à cette hauteur et grandit avec son
  /// texte jusqu'à [maxLines] : un nom court tient sur une ligne, un nom
  /// long se lit en entier au lieu de défiler hors de vue. Nul, le champ a
  /// d'emblée la hauteur de [maxLines].
  final int? minLines;

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

  /// Prend le focus (et ouvre le clavier) dès l'affichage : pour le champ
  /// UNIQUE d'une popup de saisie, qu'on ouvre précisément pour écrire.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autocorrect: autocorrect,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: inlineLabel ? (hint ?? label) : hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: prefixIconColor),
        suffixText: suffixText,
        suffixIcon: suffixIcon == null
            ? null
            : ExcludeSemantics(child: Icon(suffixIcon, color: suffixIconColor)),
      ),
    );

    // Le libellé est celui du CHAMP, pour le lecteur d'écran : posé en texte
    // frère au-dessus, il se lisait détaché (fondu dans le nœud voisin), et
    // le champ ne s'annonçait que par sa valeur — ou par son indice, lu
    // comme s'il était déjà rempli.
    final labelled = Semantics(label: label, child: field);
    if (inlineLabel) {
      return labelled;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: AppSpacing.xxs),
        labelled,
      ],
    );
  }
}

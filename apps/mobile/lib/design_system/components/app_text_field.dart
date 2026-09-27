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
  /// d'écran — une fois. Un [hint] distinct du libellé est annoncé aussi.
  final bool inlineLabel;

  /// Prend le focus (et ouvre le clavier) dès l'affichage : pour le champ
  /// UNIQUE d'une popup de saisie, qu'on ouvre précisément pour écrire.
  final bool autofocus;

  /// L'opacité d'un fantôme INACTIF chez Material : 38 % de 255, arrondi.
  static const int _disabledHintAlpha = 97;

  /// Le texte fantôme d'un champ à libellé intégré, MUET pour le lecteur
  /// d'écran — à n'employer que lorsqu'il RÉPÈTE le libellé.
  ///
  /// Le libellé y était à la fois le texte fantôme et la sémantique du
  /// champ : « Mot de passe, Mot de passe, champ de texte ». Le champ garde
  /// sa sémantique — elle seule survit à la saisie, quand le fantôme
  /// s'efface — et le fantôme se tait. Il se dessine exactement comme celui
  /// de Material (`inline_label_fields_test.dart` compare les deux) : le
  /// corps du thème, l'encre `onSurfaceVariant`, pâlie quand le champ est
  /// inactif, puis le style de fantôme du thème s'il en pose un ; et il
  /// tient dans les [maxLines] lignes du champ, ellipse au bout. Sans cette
  /// borne, « Adresse e-mail » passait sur deux lignes à 320 points en
  /// texte ×2, et le champ vide de la connexion de 68 à 112 points — qu'il
  /// gardait pendant la saisie, la place du fantôme restant réservée.
  static Widget silentHint(
    BuildContext context,
    String text, {
    required bool enabled,
    int? maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final states = {if (!enabled) WidgetState.disabled};
    final style =
        (theme.useMaterial3
                ? theme.textTheme.bodyLarge!
                : theme.textTheme.titleMedium!)
            .merge(
              TextStyle(
                color: enabled
                    ? colors.onSurfaceVariant
                    // Le 38 % de Material, arrondi comme lui à l'octet.
                    : colors.onSurface.withAlpha(_disabledHintAlpha),
              ),
            )
            .merge(
              WidgetStateProperty.resolveAs(
                theme.inputDecorationTheme.hintStyle,
                states,
              ),
            );
    // La borne de Material : celle du thème s'il en pose une, sinon les
    // lignes du champ.
    final lines = theme.inputDecorationTheme.hintMaxLines ?? maxLines;
    return ExcludeSemantics(
      child: Text(
        text,
        style: style,
        maxLines: lines,
        overflow:
            style.overflow ?? (lines == null ? null : TextOverflow.ellipsis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Le fantôme ne se tait que s'il RÉPÈTE le libellé. Un exemple distinct
    // (« Course, vélo, yoga… » dans la popup « Activité libre ») est le seul
    // texte visible du champ et dit quoi y écrire : il reste lu.
    final hintRepeatsLabel = inlineLabel && (hint == null || hint == label);
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
        // Libellé intégré répété : le fantôme se tait, le champ dit son
        // libellé (voir [silentHint]).
        hint: hintRepeatsLabel
            ? silentHint(context, label, enabled: enabled, maxLines: maxLines)
            : null,
        hintText: hintRepeatsLabel ? null : hint,
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

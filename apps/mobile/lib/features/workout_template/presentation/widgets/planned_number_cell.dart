import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/design_system.dart';

/// Une case chiffrée du tableau des séries prévues (charge, répétitions,
/// repos) : saisie au clavier numérique, centrée, comme sur la maquette.
///
/// La case garde SA saisie tant qu'elle a le focus — « 82, » est une étape
/// vers « 82,5 », pas une erreur à corriger sous le doigt — puis se remet
/// sur la valeur retenue en le perdant.
class PlannedNumberCell extends StatefulWidget {
  const PlannedNumberCell({
    required this.text,
    required this.onChanged,
    required this.semanticLabel,
    this.decimal = false,
    this.suffix,
    super.key,
  });

  /// La valeur retenue, déjà mise en forme (« 80 », « 82,5 », vide).
  final String text;
  final ValueChanged<String> onChanged;
  final String semanticLabel;

  /// Accepte une virgule (la charge) ; sinon des chiffres seulement.
  final bool decimal;

  /// Unité posée dans la case, à droite (« s » pour le repos).
  final String? suffix;

  /// La cible tactile du design system : la case entière prend le focus.
  static const double height = AppSpacing.touchTarget;

  /// Deux décimales au plus, comme la colonne `Decimal(6,2)` du serveur :
  /// « 2,125 » partirait en refus à la synchronisation.
  static final RegExp _decimalInput = RegExp(r'^\d*([.,]\d{0,2})?$');

  @override
  State<PlannedNumberCell> createState() => _PlannedNumberCellState();
}

class _PlannedNumberCellState extends State<PlannedNumberCell> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PlannedNumberCell old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Hors saisie, la case reprend la valeur du brouillon.
  void _sync() {
    if (!_focus.hasFocus && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      // Tout sélectionner : taper « 85 » remplace « 80 » sans l'effacer.
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.metricS.copyWith(
      color: AppColors.darkTextPrimary,
    );
    return Container(
      height: PlannedNumberCell.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: AppRadius.smAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            // UN nœud : le libellé sur le champ réel, focalisable et
            // éditable — posé au-dessus, il restait muet sur un nœud sans
            // action, et le champ s'annonçait par son tiret.
            child: MergeSemantics(
              child: Semantics(
                label: widget.semanticLabel,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  expands: true,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: style,
                  cursorColor: AppColors.primaryLight,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: widget.decimal,
                  ),
                  // Le pavé numérique d'iOS n'a pas de touche Entrée : un
                  // toucher ailleurs ferme le clavier.
                  onTapOutside: (_) => _focus.unfocus(),
                  inputFormatters: [
                    if (widget.decimal)
                      // Le motif porte sur TOUTE la saisie : une frappe qui
                      // le briserait (une troisième décimale) est refusée.
                      TextInputFormatter.withFunction(
                        (before, after) =>
                            PlannedNumberCell._decimalInput.hasMatch(after.text)
                            ? after
                            : before,
                      )
                    else
                      FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  // La case dessine son cadre : le style de champ du thème
                  // (fond plein, marges intérieures) n'a rien à y faire.
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hint: ExcludeSemantics(
                      child: Text(
                        '—',
                        textAlign: TextAlign.center,
                        style: style.copyWith(
                          color: AppColors.darkTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ),
          if (widget.suffix case final suffix?)
            ExcludeSemantics(
              child: Text(
                suffix,
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

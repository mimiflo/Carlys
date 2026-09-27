import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/program.dart';

/// LES SEPT JOURS vers lesquels une case peut partir.
///
/// Extrait de `program_calendar_day_sheet.dart` plutôt qu'ajouté dedans : la
/// feuille était à 206 lignes, et le plafond du dépôt est à 250 pour un
/// widget. Le découper AVANT de franchir la limite coûte moins cher que de
/// le découper après.
///
/// Le jour d'origine est présent, marqué et INERTE : le retirer ferait une
/// rangée de six qu'il faudrait relire pour comprendre, et le rendre
/// tapable proposerait un geste qui ne fait rien.
///
/// Les jours déjà passés de la semaine en cours restent proposés. Déplacer
/// une séance vers lundi quand on est jeudi est une décision qui se défend
/// — on range son calendrier après coup — et le calendrier dira « manqué »,
/// ce qui est la vérité.
///
/// Sauf un jour dont la case est déjà FAITE ([heldDays]) : l'échange
/// emportait la séance faite vers l'autre date, et le calendrier affichait
/// « fait » un jour où l'on ne s'était pas entraîné. Sa pastille reste là,
/// verte comme dans le calendrier, et INERTE.
class ProgramDayMovePicker extends StatelessWidget {
  const ProgramDayMovePicker({
    required this.currentDayOfWeek,
    required this.onMove,
    this.heldDays = const {},
    super.key,
  });

  /// 1 (lundi) à 7 (dimanche) — le jour où la case se trouve aujourd'hui.
  final int currentDayOfWeek;

  /// Les jours dont la case est honorée par une séance : ils ne se prennent
  /// pas.
  final Set<int> heldDays;

  /// Appelé avec le jour d'arrivée, dans la même convention.
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionLabel('Déplacer vers'),
        const SizedBox(height: AppSpacing.xs),
        // Une RANGÉE de sept parts égales, pas un `Wrap` : au gabarit d'un
        // téléphone, le septième jour retombait seul à la ligne suivante, et
        // une semaine dont dimanche est mis à part ne se lit plus d'un coup
        // d'œil. Chaque pastille garde sa taille naturelle, centrée dans son
        // septième — c'est la SEMAINE qu'on veut voir, pas sept boutons.
        Row(
          children: [
            for (var jour = 1; jour <= programDayLabels.length; jour++)
              Expanded(child: Center(child: _pastille(jour))),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'La séance change de jour dans la semaine. Si le jour d’arrivée '
          'est déjà pris, les deux s’échangent.'
          '${heldDays.isEmpty ? '' : ' Un jour déjà fait, en vert, ne se prend pas.'}',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
  }

  Widget _pastille(int jour) {
    final nom = programDayLabels[jour - 1];
    final actuel = jour == currentDayOfWeek;
    final tenu = !actuel && heldDays.contains(jour);
    return Semantics(
      button: !actuel && !tenu,
      selected: actuel,
      label: actuel
          ? 'Jour actuel : $nom'
          : tenu
          ? '$nom : séance déjà faite, ce jour ne se prend pas'
          : 'Déplacer vers $nom',
      child: AppPill(
        label: nom,
        mono: true,
        tone: tenu ? AppPillTone.success : AppPillTone.neutral,
        selected: actuel,
        selectedTone: AppPillTone.primary,
        onTap: actuel || tenu ? null : () => onMove(jour),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête du coach (maquette d'octobre 2026) : la porte de sortie à gauche,
/// « Coach IA / TON ENTRAÎNEMENT, À TON ÉCOUTE » au centre.
///
/// Partagé par la conversation ET par ses états d'attente ou d'erreur. Un
/// coach qui n'a pas pu s'ouvrir est précisément le moment où l'on veut
/// repartir : sans flèche, il faudrait ressortir par la barre d'onglets,
/// donc quitter Training pour y revenir.
///
/// La flèche est celle du design system : elle dépile la navigation la plus
/// proche et disparaît d'elle-même s'il n'y a rien derrière. Le coach s'ouvre
/// depuis le hub Training, il y a donc un écran à retrouver ; le jour où il
/// redeviendrait la racine d'un onglet, rien à changer ici.
class CoachHeader extends StatelessWidget {
  const CoachHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      // La marge serrée de l'ancien en-tête, et non la gouttière : la ligne
      // mono tient sur une ligne dès 393 points, et passe à la ligne, sans
      // déborder, sur plus étroit.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: AppScreenHeader.centered(
        title: 'Coach IA',
        tagline: 'Ton entraînement, à ton écoute',
      ),
    );
  }
}

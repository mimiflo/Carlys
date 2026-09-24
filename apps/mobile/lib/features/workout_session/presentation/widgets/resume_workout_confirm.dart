import 'package:flutter/widgets.dart';

import '../../../../design_system/design_system.dart';

/// La question posée quand on lance une séance alors qu'une autre tourne.
///
/// Le domaine impose AU PLUS UNE séance en cours : on ne remplace jamais
/// celle qui tourne, on propose de la reprendre. Deux écrans lancent une
/// séance (les modèles, le calendrier du programme) ; ils posaient la même
/// question en deux boîtes recopiées, elle vit désormais ici, une fois.
///
/// Rend `true` si la personne choisit de reprendre la séance en cours.
Future<bool> showResumeWorkoutConfirm(BuildContext context) {
  return showAppConfirm(
    context,
    title: 'Une séance est en cours',
    message: 'Termine-la avant d’en lancer une autre.',
    confirmLabel: 'Reprendre la séance',
    cancelLabel: 'Plus tard',
    icon: AppIcons.confirmResume,
  );
}

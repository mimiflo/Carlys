/// LA GRAMMAIRE DES CARTES MAÎTRESSES DE PROGRÈS.
///
/// Relevée sur la maquette et partagée par la carte de volume et la carte de
/// poids : gouttière de 20, libellé à 6 de sa valeur, valeur mono à 30
/// resserrée, unité à 15. Elle sort de l'échelle générale (`AppSpacing`) à
/// dessein — ce sont les deux plus grandes surfaces de l'écran, et leur
/// respiration est plus large que celle d'une carte ordinaire.
///
/// Elle était DÉCLARÉE dans `body_weight_latest.dart`, avec la note « nommées
/// ici plutôt qu'écrites dans les widgets », et malgré cela recopiée en clair
/// dans `volume_card.dart`. Deux copies d'une même grammaire finissent par
/// diverger : l'une se corrige, l'autre reste. Elle n'existe donc plus qu'à
/// un seul endroit, et ce fichier est cet endroit.
///
/// Si un TROISIÈME usage apparaît, ces valeurs montent en jetons
/// (`packages/design-tokens/src/tokens.json`), qui est la source de vérité du
/// design system.
library;

import 'package:flutter/widgets.dart';

const EdgeInsets progressCardPadding = EdgeInsets.all(20);

/// Écart entre le libellé de la carte et la valeur qu'il annonce.
const double progressCardLabelGap = 6;

const double progressCardValueFontSize = 30;
const double progressCardValueLetterSpacing = -1.2;

/// L'unité se rend plus petite que la valeur, collée à elle.
const double progressCardUnitFontSize = 15;

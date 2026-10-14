import 'package:flutter/painting.dart';

import '../../../../design_system/design_system.dart';

/// Le surlignage de « MOI » dans un classement de la communauté : ma ligne
/// de ligue, ma ligne de défi entre amis et mon dernier résultat de ligue.
const meHighlight = BoxDecoration(
  color: AppColors.primaryBadgeBg,
  borderRadius: AppRadius.mdAll,
  border: Border.fromBorderSide(
    BorderSide(color: AppColors.primaryBadgeBorder),
  ),
);

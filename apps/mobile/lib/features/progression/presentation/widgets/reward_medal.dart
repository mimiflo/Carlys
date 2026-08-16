import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';

/// LA GRAVURE.
///
/// Une récompense fraîchement obtenue ne s'affiche pas : elle SE GRAVE. Le
/// contour se trace d'un trait continu, puis le sceau se remplit et le
/// symbole apparaît. C'est le seul moment où l'application se permet une
/// célébration, et elle ne dure qu'une seconde.
///
/// Elle ne rejoue jamais. Une gravure qui se rejouerait à chaque ouverture
/// perdrait exactement ce qui en fait le prix : elle marque un instant, pas
/// un état. C'est [EarnedReward.isNew], donc le journal, qui en décide.
///
/// La réduction d'animations système est respectée : le sceau est alors
/// simplement là, entier, sans mouvement.
class RewardMedal extends StatefulWidget {
  const RewardMedal({
    required this.reward,
    this.isNew = false,
    this.size = 56,
    super.key,
  });

  final Reward reward;

  /// Obtenue à l'instant : elle se grave. Sinon elle est simplement là.
  final bool isNew;

  final double size;

  /// Durée de la gravure : le trait, puis le remplissage.
  static const Duration engraveDuration = Duration(milliseconds: 900);

  @override
  State<RewardMedal> createState() => _RewardMedalState();
}

class _RewardMedalState extends State<RewardMedal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RewardMedal.engraveDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.isNew) {
      _controller.value = 1;
      return;
    }
    _controller.duration =
        AppMotion.resolve(context, RewardMedal.engraveDuration);
    if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.reward.kind.label} : ${widget.reward.label}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              painter: MedalPainter(
                progress: _controller.value,
                kind: widget.reward.kind,
              ),
              child: child,
            ),
            child: Center(
              child: FadeTransition(
                // Le symbole n'apparaît qu'une fois le sceau fermé : le voir
                // avant son cadre casserait l'idée même de gravure.
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.62, 1),
                ),
                child: Icon(
                  _icon(widget.reward.kind),
                  size: widget.size * 0.4,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(RewardKind kind) => switch (kind) {
        RewardKind.badge => AppIcons.badge,
        RewardKind.medaille => AppIcons.medal,
        RewardKind.certificat => AppIcons.certificate,
        RewardKind.record => AppIcons.record,
        RewardKind.titre => AppIcons.crown,
      };
}

/// Le sceau : un anneau qui se trace, puis un fond qui monte.
///
/// Public pour les tests : l'avancement de la gravure est la seule chose
/// qu'ils peuvent lire, un dessin ne se relit pas autrement.
@visibleForTesting
class MedalPainter extends CustomPainter {
  const MedalPainter({required this.progress, required this.kind});

  final double progress;
  final RewardKind kind;

  /// Part de l'animation consacrée au TRACÉ. Le reste remplit.
  static const double _strokeShare = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final traced = (progress / _strokeShare).clamp(0.0, 1.0);
    final filled =
        ((progress - _strokeShare) / (1 - _strokeShare)).clamp(0.0, 1.0);

    if (filled > 0) {
      // L'opacité passe par un CALQUE : posée sur le `Paint`, elle serait
      // ignorée, un dégradé apportant sa propre couleur.
      canvas
        ..saveLayer(
          rect,
          Paint()..color = AppColors.neutral0.withValues(alpha: filled),
        )
        ..drawCircle(
          center,
          radius,
          Paint()..shader = _fill(kind).createShader(rect),
        )
        ..restore();
    }

    // Le trait part du HAUT et tourne dans le sens des aiguilles : c'est le
    // geste d'un burin, pas celui d'une jauge.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * traced,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = _stroke(kind),
    );
  }

  static Color _stroke(RewardKind kind) => switch (kind) {
        RewardKind.badge => AppColors.primaryLight,
        RewardKind.medaille => AppColors.primary,
        RewardKind.certificat => AppColors.accent,
        RewardKind.record => AppColors.accent,
        RewardKind.titre => AppColors.primary,
      };

  static Gradient _fill(RewardKind kind) => switch (kind) {
        RewardKind.badge => AppColors.violetRamp,
        RewardKind.medaille => AppColors.signature,
        RewardKind.certificat => AppColors.energy,
        RewardKind.record => AppColors.energy,
        RewardKind.titre => AppColors.signature,
      };

  @override
  bool shouldRepaint(MedalPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.kind != kind;
}

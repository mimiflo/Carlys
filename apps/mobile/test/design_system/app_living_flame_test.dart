import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La flamme de série respire EN PERMANENCE sur l'accueil : son mouvement ne
/// doit repeindre qu'elle-même. Sans frontière de repeinture, chaque image
/// de sa respiration repeignait tout ce qui partage sa couche — la liste de
/// l'accueil entière, soixante fois par seconde.
void main() {
  testWidgets('la respiration ne repeint pas ce qui l’entoure', (tester) async {
    final voisin = _CountingPainter();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            const AppLivingFlame(size: 14, color: AppColors.accent),
            CustomPaint(painter: voisin, size: const Size(100, 100)),
          ],
        ),
      ),
    );
    final avant = voisin.paints;

    // Cinq secondes d'accueil à 60 Hz.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(voisin.paints - avant, 0);
  });
}

class _CountingPainter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => false;
}

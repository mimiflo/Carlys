import 'package:carlys_mobile/features/workout_session/data/dto/workout_session_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

/// La révision de séance (`revision`, entier, `packages/api-contracts/src/
/// workouts.ts`) est lue dans la LISTE comme dans le DÉTAIL : c'est leur
/// égalité qui dispense le rapatriement de relire une séance.
void main() {
  const summary = {'id': 's-1', 'startedAt': '2026-09-01T17:00:00.000Z'};
  const detail = {...summary, 'status': 'COMPLETED'};

  test('la liste et le détail portent la révision servie', () {
    expect(sessionRefFromJson({...summary, 'revision': 4}).revision, 4);
    expect(sessionFromJson({...detail, 'revision': 5}).revision, 5);
  });

  test('un serveur plus ancien ne la sert pas : nulle, donc relue', () {
    expect(sessionRefFromJson(summary).revision, isNull);
    expect(sessionFromJson(detail).revision, isNull);
  });
}

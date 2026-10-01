import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les amorces lancent la conversation du jour : une fois que la personne a
/// écrit aujourd'hui, elles s'effacent jusqu'au lendemain.
void main() {
  final now = DateTime(2026, 10, 1, 14);

  CoachMessage message(CoachRole role, DateTime? at) =>
      CoachMessage(id: '$role$at', role: role, content: '…', createdAt: at);

  test('une question posée aujourd’hui (jour local) : déjà écrit', () {
    expect(
      coachWroteToday([
        message(CoachRole.user, DateTime(2026, 10, 1, 0, 5)),
      ], now),
      isTrue,
    );
    // Le serveur date en UTC : c'est le jour LOCAL qui compte.
    expect(
      coachWroteToday([
        message(CoachRole.user, DateTime(2026, 10, 1, 9).toUtc()),
      ], now),
      isTrue,
    );
  });

  test('hier, une réponse du coach seule, ou sans date : pas encore écrit', () {
    expect(coachWroteToday(const [], now), isFalse);
    expect(
      coachWroteToday([
        message(CoachRole.user, DateTime(2026, 9, 30, 23, 50)),
      ], now),
      isFalse,
    );
    expect(
      coachWroteToday([
        message(CoachRole.assistant, DateTime(2026, 10, 1, 9)),
      ], now),
      isFalse,
    );
    expect(coachWroteToday([message(CoachRole.user, null)], now), isFalse);
  });
}

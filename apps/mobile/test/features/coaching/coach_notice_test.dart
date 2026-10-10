import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach_thread_state.dart';
import 'package:carlys_mobile/features/coaching/presentation/utils/coach_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque refus a sa nature : l’écran en tire titre et icône', () {
    final cases = <AppException, CoachRefusalKind>{
      const ServerException('x', statusCode: 503, code: 'SERVICE_BUSY'):
          CoachRefusalKind.busy,
      const ServerException('coupé', statusCode: 503): CoachRefusalKind.paused,
      const ServerException('limite', statusCode: 429, fromApi: true):
          CoachRefusalKind.limit,
      const ServerException('proxy', statusCode: 429): CoachRefusalKind.limit,
      const ValidationException('déjà', statusCode: 409):
          CoachRefusalKind.pending,
      const ServerException('déjà', statusCode: 409): CoachRefusalKind.pending,
      const ValidationException(
        'même id',
        statusCode: 409,
        code: 'IDENTIFIER_CONFLICT',
      ): CoachRefusalKind.failed,
      const ServerException('boum', statusCode: 500): CoachRefusalKind.failed,
      const UnknownException('?'): CoachRefusalKind.failed,
    };
    for (final MapEntry(key: exception, value: kind) in cases.entries) {
      expect(coachNoticeFor(exception)?.kind, kind, reason: '$exception');
    }
  });

  test('le 429 de l’API garde sa phrase, celui d’un intermédiaire non', () {
    expect(
      coachNoticeFor(
        const ServerException(
          'Plafond du jour.',
          statusCode: 429,
          fromApi: true,
        ),
      )?.message,
      'Plafond du jour.',
    );
    expect(
      coachNoticeFor(const ServerException('<html>', statusCode: 429))?.message,
      isNot('<html>'),
    );
  });

  test('hors ligne : pas d’avis, le composeur le dit déjà', () {
    expect(coachNoticeFor(const NetworkException('coupé')), isNull);
  });
}

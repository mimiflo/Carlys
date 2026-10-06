import 'package:carlys_mobile/features/workout_session/domain/services/rest_alarm.dart';

/// La fin de repos, sans greffon : les tests n'ont pas de système à qui la
/// confier. Note ce que le minuteur a demandé.
class FakeRestAlarm implements RestAlarm {
  final List<String> calls = [];

  @override
  Future<void> schedule(Duration after) async =>
      calls.add('sonner dans ${after.inSeconds} s');

  @override
  Future<void> cancel() async => calls.add('annuler');
}

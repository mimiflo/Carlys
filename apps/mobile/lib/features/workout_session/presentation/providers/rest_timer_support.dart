import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État du minuteur de repos.
class RestTimerState {
  const RestTimerState({required this.total, required this.remaining});

  final Duration total;
  final Duration remaining;

  double get progress =>
      total.inSeconds == 0 ? 0 : remaining.inSeconds / total.inSeconds;
}

/// L'heure du minuteur de repos (remplacée en test : écran éteint simulé).
final restClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

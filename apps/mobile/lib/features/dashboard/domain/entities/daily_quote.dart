/// La maxime du jour, et la valeur Carlys qu'elle porte.
library;

import '../../../../core/brand/carlys_value.dart';

export '../../../../core/brand/carlys_value.dart' show CarlysValue;

/// Maxime du jour : une phrase, la valeur qu'elle sert.
class DailyQuote {
  const DailyQuote({required this.text, required this.value});

  final String text;
  final CarlysValue value;
}

/// La maxime du jour, la valeur Carlys qu'elle porte, et les états où elle
/// a quelque chose à dire.
library;

import '../../../../core/brand/carlys_value.dart';
import 'quote_context.dart';

export '../../../../core/brand/carlys_value.dart' show CarlysValue;
export 'quote_context.dart';

/// Une maxime du corpus, avant composition : son texte et ses étiquettes.
///
/// La VALEUR n'est pas ici — elle est portée par le fichier, comme avant.
/// Une liste par valeur rend l'entrelacement structurel au lieu de le
/// confier à la vigilance de qui ajoute une entrée.
class QuoteEntry {
  const QuoteEntry(this.text, {this.contexts = const {}});

  final String text;

  /// Vide = maxime de ROTATION, servie un jour sur N quoi qu'il arrive.
  /// Non vide = maxime CONTEXTUELLE, qui ne sort que quand son fait est
  /// vrai, et qui ne tombe jamais dans la rotation.
  final Set<QuoteContext> contexts;
}

/// Maxime du jour : une phrase, la valeur qu'elle sert, ses contextes.
class DailyQuote {
  const DailyQuote({
    required this.text,
    required this.value,
    this.contexts = const {},
  });

  final String text;
  final CarlysValue value;
  final Set<QuoteContext> contexts;

  /// Vrai pour une maxime de rotation — celles, et celles-là seules, que le
  /// repli calendaire a le droit de servir.
  bool get isRotating => contexts.isEmpty;
}

/// Formatage des valeurs affichées — source unique pour toute l'app.
///
/// La refonte impose un format précis et cohérent d'un écran à l'autre :
/// milliers séparés par une espace fine insécable (« 1 840 »), décimales à la
/// virgule (« 82,5 »), volumes en tonnes au-delà de 1 000 kg (« 6,4 t »),
/// dates relatives en majuscules mono (« IL Y A 4 JOURS »).
library;

/// Espace fine insécable : sépare les milliers sans jamais casser la ligne.
const String _thinSpace = '\u202F';

const List<String> _monthsLong = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const List<String> _monthsShort = [
  'JANV.',
  'FÉVR.',
  'MARS',
  'AVR.',
  'MAI',
  'JUIN',
  'JUIL.',
  'AOÛT',
  'SEPT.',
  'OCT.',
  'NOV.',
  'DÉC.',
];

const List<String> _weekdaysShort = [
  'LUN.',
  'MAR.',
  'MER.',
  'JEU.',
  'VEN.',
  'SAM.',
  'DIM.',
];

const List<String> _weekdaysLong = [
  'LUNDI',
  'MARDI',
  'MERCREDI',
  'JEUDI',
  'VENDREDI',
  'SAMEDI',
  'DIMANCHE',
];

/// « 1840 » → « 1 840 ». Les négatifs gardent leur signe.
String formatThousands(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(_thinSpace);
    }
    buffer.write(digits[i]);
  }
  return rounded < 0 ? '-$buffer' : buffer.toString();
}

/// « 82.5 » → « 82,5 » ; « 80.0 » → « 80 ». Les milliers restent séparés.
String formatDecimal(double value, {int decimals = 1}) {
  if (value == value.roundToDouble()) {
    return formatThousands(value);
  }
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final integerPart = formatThousands(double.parse(parts.first));
  final fraction = parts.length > 1 ? parts[1] : '';
  return fraction.isEmpty ? integerPart : '$integerPart,$fraction';
}

/// Volume : au-delà de 1 000 kg la maquette bascule en tonnes (« 6,4 t »).
/// Renvoie la valeur et son unité séparément — l'unité se rend en plus petit.
({String value, String unit}) formatVolume(double kilograms) {
  if (kilograms >= 1000) {
    return (value: formatDecimal(kilograms / 1000), unit: 't');
  }
  return (value: formatThousands(kilograms), unit: 'kg');
}

/// « 54 MIN » ; au-delà de l'heure « 1 H 05 ».
String formatDurationShort(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '$minutes MIN';
  }
  final rest = minutes % 60;
  return '${minutes ~/ 60} H ${rest.toString().padLeft(2, '0')}';
}

/// Chronomètre de séance : « 18:42 », ou « 1:18:42 » au-delà de l'heure.
String formatChrono(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final h = safe ~/ 3600;
  final m = (safe % 3600) ~/ 60;
  final s = safe % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// « novembre 2025 » — sélecteur de mois de l'historique.
String formatMonthYear(DateTime date) =>
    '${_monthsLong[date.month - 1]} ${date.year}';

/// « Novembre 2025 » — en-tête de la carte calendaire.
String formatMonthYearCapitalized(DateTime date) {
  final month = _monthsLong[date.month - 1];
  return '${month[0].toUpperCase()}${month.substring(1)} ${date.year}';
}

/// « MARDI 12 NOV. » — en-tête d'accueil.
String formatLongDateMono(DateTime date) =>
    '${_weekdaysLong[date.weekday - 1]} ${date.day} '
    '${_monthsShort[date.month - 1]}';

/// « LUN. 11 NOV. » — sous-titre des cartes de séance.
String formatShortDateMono(DateTime date) =>
    '${_weekdaysShort[date.weekday - 1]} ${date.day} '
    '${_monthsShort[date.month - 1]}';

/// « MARS 2025 » — « membre depuis ».
String formatMonthYearMono(DateTime date) =>
    '${_monthsShort[date.month - 1].replaceAll('.', '')} ${date.year}';

/// « AUJOURD'HUI », « HIER », « IL Y A 4 JOURS », « IL Y A 3 SEMAINES »,
/// « IL Y A 5 MOIS ». Calculé en jours calendaires locaux.
String formatRelativeDayMono(DateTime date, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toLocal();
  final local = date.toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;

  if (days <= 0) {
    return 'AUJOURD’HUI';
  }
  if (days == 1) {
    return 'HIER';
  }
  if (days < 7) {
    return 'IL Y A $days JOURS';
  }
  if (days < 31) {
    final weeks = days ~/ 7;
    return 'IL Y A $weeks SEMAINE${weeks > 1 ? 'S' : ''}';
  }
  final months = days ~/ 30;
  return 'IL Y A $months MOIS';
}

/// Heure relative courte d'un fil social : « il y a 2 h », « hier »…
///
/// Volontairement grossière — un fil d'encouragements n'a pas besoin de la
/// minute près, et une précision fausse (l'horloge de l'appareil) se
/// remarquerait plus qu'une échelle honnête.
String formatRelativeTime(DateTime date, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(date);
  if (difference.inMinutes < 1) {
    return 'à l’instant';
  }
  if (difference.inHours < 1) {
    return 'il y a ${difference.inMinutes} min';
  }
  if (difference.inHours < 24) {
    return 'il y a ${difference.inHours} h';
  }
  if (difference.inDays == 1) {
    return 'hier';
  }
  if (difference.inDays < 7) {
    return 'il y a ${difference.inDays} jours';
  }
  return formatShortDateMono(date).toLowerCase();
}

/// « 2026-08-11 » — clé de JOUR LOCAL (réponses de quiz, bornes de journée).
/// Le serveur ne découpe jamais les journées : c'est l'appareil qui sait où
/// commence « aujourd'hui ».
String formatDayKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

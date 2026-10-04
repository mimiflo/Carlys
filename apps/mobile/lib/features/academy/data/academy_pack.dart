/// Chargement du pack d'apprentissage embarqué (`assets/academy/pack.json`).
library;

import '../../../core/utilities/embedded_pack.dart';
import '../domain/entities/academy.dart';

final _pack = EmbeddedPack<Lesson>(
  asset: 'assets/academy/pack.json',
  listKey: 'lessons',
  parse: _lesson,
  emptyMessage: 'pack d’apprentissage vide',
);

Future<List<Lesson>> loadAcademyPack() => _pack.load();

/// Réservé aux tests, qui vérifient le rechargement.
void resetAcademyPackCache() => _pack.reset();

Lesson _lesson(Map<String, dynamic> json) {
  final question = json['question'] as Map<String, dynamic>;
  final choices = (question['choices'] as List<dynamic>).cast<String>().toList(
    growable: false,
  );
  final answerIndex = question['answerIndex'] as int;
  if (answerIndex < 0 || answerIndex >= choices.length) {
    throw FormatException('réponse hors bornes pour ${json['id']}');
  }
  return Lesson(
    id: json['id'] as String,
    category: AcademyCategory.values.byName(json['category'] as String),
    title: json['title'] as String,
    body: json['body'] as String,
    // Champs optionnels : une leçon minimale (titre, corps, question) reste
    // valide — points, groupes et illustration l'enrichissent.
    points: (json['points'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList(growable: false),
    muscleGroupSlugs: (json['muscleGroups'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList(growable: false),
    image: json['image'] as String?,
    imageRatio:
        (json['imageRatio'] as num?)?.toDouble() ?? Lesson.defaultImageRatio,
    question: QuizQuestion(
      prompt: question['prompt'] as String,
      choices: choices,
      answerIndex: answerIndex,
      explanation: question['explanation'] as String,
    ),
  );
}

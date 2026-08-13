/// Le contenu d'apprentissage : des leçons courtes, chacune portée par une
/// question à choix. C'est un contenu ÉDITORIAL embarqué — pas une donnée
/// serveur : il voyage avec l'application, comme les vignettes de muscles.
library;

/// Domaines couverts par l'Academy.
enum AcademyCategory {
  anatomie('Anatomie'),
  technique('Technique'),
  nutrition('Nutrition'),
  recuperation('Récupération');

  const AcademyCategory(this.label);

  final String label;
}

/// Une question à choix unique, avec son explication.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
  });

  final String prompt;
  final List<String> choices;
  final int answerIndex;

  /// Toujours affichée après la réponse — juste ou fausse : c'est elle qui
  /// apprend quelque chose, pas le verdict.
  final String explanation;
}

/// Une leçon : un titre, un corps court, l'essentiel à retenir, une
/// question pour l'ancrer — et, pour l'anatomie, le pont vers la pratique.
class Lesson {
  const Lesson({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.question,
    this.points = const [],
    this.muscleGroupSlugs = const [],
    this.image,
  });

  final String id;
  final AcademyCategory category;
  final String title;
  final String body;
  final QuizQuestion question;

  /// « À retenir » : trois idées maximum, actionnables — c'est ce qui reste
  /// quand le corps de la leçon est oublié.
  final List<String> points;

  /// Groupes musculaires enseignés (slugs du catalogue) : la leçon propose
  /// alors d'ouvrir la bibliothèque d'exercices filtrée dessus — apprendre,
  /// puis pratiquer, en un geste.
  final List<String> muscleGroupSlugs;

  /// Illustration embarquée (`assets/academy/<id>.webp`). Tant que le
  /// fichier n'existe pas, la carte pose un repli — jamais un trou.
  final String? image;
}

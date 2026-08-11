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

/// Une leçon : un titre, un corps court, une question pour l'ancrer.
class Lesson {
  const Lesson({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.question,
  });

  final String id;
  final AcademyCategory category;
  final String title;
  final String body;
  final QuizQuestion question;
}

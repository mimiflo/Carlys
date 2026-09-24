import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import '../controllers/academy_controllers.dart';
import '../widgets/quiz_card.dart';

/// Le quiz d'un domaine : ses questions rejouées d'un trait, une à la fois.
///
/// Il s'ouvre depuis l'en-tête d'un domaine BOUCLÉ : c'est une répétition
/// pour ancrer, pas un examen d'entrée. Le score s'affiche à la fin puis
/// meurt avec l'écran, PAR CONSTRUCTION : cet écran ne lit que le pack et
/// n'écrit nulle part — ni magasin de réponses, ni défis culturels, ni
/// récompense. Un score conservé serait une note de la personne, ce que la
/// règle de non-concurrence (`docs/product/progression.md`) interdit ; les
/// réponses aux leçons, elles, sont déjà notées à la première lecture.
class DomainQuizScreen extends ConsumerStatefulWidget {
  const DomainQuizScreen({required this.domaine, super.key});

  /// Nom de l'énumération [AcademyCategory] (clé du pack), pas le libellé.
  final String domaine;

  @override
  ConsumerState<DomainQuizScreen> createState() => _DomainQuizScreenState();
}

class _DomainQuizScreenState extends ConsumerState<DomainQuizScreen> {
  int _index = 0;
  int _bonnes = 0;
  bool _repondu = false;
  bool _termine = false;

  void _reponse(bool correct) {
    setState(() {
      _repondu = true;
      if (correct) {
        _bonnes++;
      }
    });
  }

  void _suivante(int total) {
    setState(() {
      if (_index + 1 >= total) {
        _termine = true;
      } else {
        _index++;
        _repondu = false;
      }
    });
  }

  void _refaire() {
    setState(() {
      _index = 0;
      _bonnes = 0;
      _repondu = false;
      _termine = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categorie = AcademyCategory.values
        .where((c) => c.name == widget.domaine)
        .firstOrNull;
    final pack = ref.watch(academyPackProvider);

    return AppDarkScaffold(
      appBar: AppBar(
        title: Text(categorie == null ? 'Quiz' : 'Quiz ${categorie.label}'),
      ),
      body: pack.when(
        loading: () => const AppLoadingIndicator(),
        error: (error, _) => AppErrorState(
          title: 'Quiz indisponible',
          message: 'Le contenu d’apprentissage n’a pas pu être chargé.',
          onRetry: () => ref.invalidate(academyPackProvider),
        ),
        data: (lessons) {
          final duDomaine = categorie == null
              ? const <Lesson>[]
              : lessons
                    .where((lesson) => lesson.category == categorie)
                    .toList();
          if (duDomaine.isEmpty) {
            return const AppEmptyState(
              title: 'Rien à rejouer ici',
              message: 'Ce domaine n’a pas encore de leçons.',
            );
          }
          return _termine
              ? _Resultat(
                  bonnes: _bonnes,
                  total: duDomaine.length,
                  onRefaire: _refaire,
                )
              : _Question(
                  lesson: duDomaine[_index],
                  index: _index,
                  total: duDomaine.length,
                  repondu: _repondu,
                  onAnswered: _reponse,
                  onSuivante: () => _suivante(duDomaine.length),
                );
        },
      ),
    );
  }
}

/// Une question, sa position, et le pas suivant une fois répondu.
class _Question extends StatelessWidget {
  const _Question({
    required this.lesson,
    required this.index,
    required this.total,
    required this.repondu,
    required this.onAnswered,
    required this.onSuivante,
  });

  final Lesson lesson;
  final int index;
  final int total;
  final bool repondu;
  final void Function(bool correct) onAnswered;
  final VoidCallback onSuivante;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        bottomInset + AppSpacing.gapSection,
      ),
      children: [
        Text(
          'Question ${index + 1} sur $total',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AppGauge(
          progress: (index + 1) / total,
          color: AppColors.primaryLight,
          height: 3,
        ),
        const SizedBox(height: AppSpacing.gapRow),
        // La MÊME carte que partout ailleurs : la clé force une carte neuve
        // par question, sinon l'état « répondu » suivrait le widget.
        QuizCard(
          key: ValueKey(lesson.id),
          question: lesson.question,
          title: lesson.title,
          hint: 'Touche une réponse. Ici, rien n’est noté.',
          onAnswered: (_, correct) => onAnswered(correct),
        ),
        if (repondu) ...[
          const SizedBox(height: AppSpacing.gapRow),
          AppButton(
            label: index + 1 >= total
                ? 'Voir le résultat'
                : 'Question suivante',
            onPressed: onSuivante,
          ),
        ],
      ],
    );
  }
}

/// Le score, dit une fois puis oublié — c'est écrit dessus.
class _Resultat extends StatelessWidget {
  const _Resultat({
    required this.bonnes,
    required this.total,
    required this.onRefaire,
  });

  final int bonnes;
  final int total;
  final VoidCallback onRefaire;

  @override
  Widget build(BuildContext context) {
    final sansFaute = bonnes >= total;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: AppSpacing.gapSection),
        Center(
          child: Text(
            '$bonnes / $total',
            style: AppTypography.pageTitle.copyWith(
              color: sansFaute ? AppColors.accent : AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            sansFaute
                ? 'Sans faute. Ce domaine est à toi.'
                : 'Chaque erreur a montré son explication : c’est elle qui '
                      'reste.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            'Ce score reste ici : rien n’est enregistré, refais-le quand '
            'tu veux.',
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.gapSection),
        AppButton(label: 'Refaire le quiz', onPressed: onRefaire),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Retour à l’Academy',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

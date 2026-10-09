import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/services/coach_greeting.dart';
import '../../domain/services/coach_suggestions.dart';
import 'coach_greeting_bubble.dart';
import 'coach_notices.dart';

/// Un fil vide (maquette d'octobre 2026) : l'emblème, « Ton coach est là »,
/// le profil Carlys qui oriente ses réponses, puis « Pour commencer » — les
/// amorces en cartes — et, au premier rang du fil à venir, son bonjour
/// ([greeting]) quand la page en a écrit un.
class CoachIntro extends StatelessWidget {
  const CoachIntro({
    required this.greeting,
    required this.suggestions,
    required this.onSelected,
    required this.bubbleWidthFactor,
    this.profileLabel,
    this.onOpenProfile,
    super.key,
  });

  final CoachGreeting? greeting;
  final List<CoachSuggestion> suggestions;
  final ValueChanged<String> onSelected;
  final double bubbleWidthFactor;

  /// « Stratège » : le profil Carlys choisi, `null` tant qu'il ne l'est pas.
  final String? profileLabel;
  final VoidCallback? onOpenProfile;

  static const double _emblemSize = 96;

  @override
  Widget build(BuildContext context) {
    final greeting = this.greeting;
    final profile = profileLabel;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          // Taille naturelle, jamais rognée (clavier ouvert, texte
          // agrandi) : le tout défile quand la place manque.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const Center(
                    child: AppIconBadge(
                      icon: AppIcons.coachEmblem,
                      size: _emblemSize,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      'Ton coach est là',
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    greeting == null
                        ? 'Pose-lui une question sur ta progression, ou '
                              'demande-lui d’adapter ta séance à ton temps '
                              'du jour.'
                        : 'Il lit tes séances, tes records et tes mesures '
                              'avant de te répondre.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: _ProfilePill(label: profile, onTap: onOpenProfile),
                    ),
                  ],
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.gapSection),
                    const AppSectionLabel('Pour commencer'),
                    const SizedBox(height: AppSpacing.sm),
                    for (final suggestion in suggestions) ...[
                      _SuggestionCard(
                        suggestion: suggestion,
                        onTap: () => onSelected(suggestion.text),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (greeting != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: CoachGreetingBubble(
                        text: greeting.text,
                        since: greeting.at,
                        maxWidth: constraints.maxWidth * bubbleWidthFactor,
                      ),
                    ),
                  // Où partent les données citées : posé là où l'on va
                  // écrire, et pas seulement dans la politique de
                  // confidentialité.
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: CoachDataNotice(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Ton profil : $label${onTap == null ? '' : '. Changer'}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.darkSurface,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.darkBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.mentor, color: AppColors.primaryLight),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Ton profil : ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final CoachSuggestion suggestion;
  final VoidCallback onTap;

  static IconData _iconOf(CoachSuggestionKind kind) => switch (kind) {
    CoachSuggestionKind.adapt => AppIcons.time,
    CoachSuggestionKind.understand => AppIcons.dailyQuestion,
    CoachSuggestionKind.progress => AppIcons.trendingUp,
    CoachSuggestionKind.weight => AppIcons.bodyMetrics,
    CoachSuggestionKind.start => AppIcons.coach,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: suggestion.text,
      onTap: onTap,
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            AppIconBadge(icon: _iconOf(suggestion.kind)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                suggestion.text,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(AppIcons.chevronRight, color: AppColors.primaryLight),
          ],
        ),
      ),
    );
  }
}

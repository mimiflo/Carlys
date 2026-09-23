import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../../carlys_profile/presentation/widgets/carlys_profile_content.dart';
import 'profile_hub_tile.dart';
import 'profile_stats_row.dart';

/// Qui tu es sur Carlys : l'initiale, le nom, l'ancienneté, ta phrase —
/// puis les trois chiffres qui racontent ton parcours.
///
/// La phrase est celle du PROFIL CARLYS choisi (« Je me prépare pour
/// quelque chose. ») : aucune devise libre n'existe dans le domaine, et en
/// inventer une serait mettre des mots dans la bouche de la personne. Sans
/// profil choisi, la ligne s'efface. La carte ouvre ce choix.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    required this.user,
    required this.onOpen,
    super.key,
  });

  final AuthUser? user;
  final VoidCallback onOpen;

  static const double _chevronSize = 24;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';
    final since = user?.createdAt;
    final profile = user?.carlysProfile;
    final quote = profile == null
        ? null
        : carlysProfileContentOf(profile).quote;
    final secondary = AppTypography.body.copyWith(
      color: AppColors.darkTextSecondary,
    );

    return ProfileHubCard(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              hint: 'Ouvre ton profil Carlys',
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _Initial(name: name),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name.isEmpty ? 'Ton profil' : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.resized(
                                          AppTypography.title,
                                          19,
                                        ).copyWith(
                                          color: AppColors.darkTextPrimary,
                                        ),
                                  ),
                                ),
                                const Icon(
                                  AppIcons.chevronRight,
                                  size: _chevronSize,
                                  color: AppColors.darkTextSecondary,
                                ),
                              ],
                            ),
                            if (since != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Membre depuis '
                                '${formatMonthYear(since.toLocal())}',
                                style: secondary,
                              ),
                            ],
                            if (quote != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(quote, style: secondary),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: ProfileStatsRow(),
            ),
          ],
        ),
      ],
    );
  }
}

/// L'initiale sur un disque violet profond, cerclé d'un filet de marque.
class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          color: AppColors.surfaceIcon,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.primaryBadgeBorder, width: 1.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: AppTypography.resized(
            AppTypography.display,
            34,
          ).copyWith(letterSpacing: 0, color: AppColors.neutral0),
        ),
      ),
    );
  }
}

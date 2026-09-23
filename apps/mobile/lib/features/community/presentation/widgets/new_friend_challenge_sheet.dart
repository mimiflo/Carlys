import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/friend_challenge.dart';

/// Les trois durées offertes. Un défi « entre amis » de quatre cents jours
/// n'est plus un défi, c'est une dette — et le serveur refuse tout ce qui
/// n'est pas dans cette liste.
const List<int> friendChallengeDurations = [3, 7, 30];

/// Le mot facultatif d'un défi : 280 caractères au plus, comme un
/// encouragement (`FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH` côté serveur).
const int friendChallengeMessageMaxLength = 280;

/// Feuille « Défier mes amis » : un titre, un mot facultatif, une unité, une
/// durée, des amis.
///
/// La fin du défi n'est pas demandée : le serveur la CALCULE depuis la
/// durée. Un écran qui l'enverrait poserait un défi éternel en une requête.
Future<NewFriendChallenge?> showNewFriendChallengeSheet(
  BuildContext context, {
  required List<CommunityFriend> friends,
}) {
  return showAppSheet<NewFriendChallenge>(
    context,
    builder: (_) => _NewFriendChallengeForm(friends: friends),
  );
}

class _NewFriendChallengeForm extends StatefulWidget {
  const _NewFriendChallengeForm({required this.friends});

  final List<CommunityFriend> friends;

  @override
  State<_NewFriendChallengeForm> createState() =>
      _NewFriendChallengeFormState();
}

class _NewFriendChallengeFormState extends State<_NewFriendChallengeForm> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Set<String> _invites = {};

  ChallengeMetric _metric = ChallengeMetric.workouts;
  int _duration = 7;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_invites.isEmpty) {
      // Un défi contre personne n'en est pas un — et le serveur le refuse
      // aussi, en 400. Le dire ici évite l'aller-retour.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis au moins un ami à défier.')),
      );
      return;
    }
    Navigator.of(context).pop(
      NewFriendChallenge(
        title: _title.text.trim(),
        metric: _metric,
        durationDays: _duration,
        invitedUserIds: _invites.toList(growable: false),
        message: _message.text.trim().isEmpty ? null : _message.text.trim(),
      ),
    );
  }

  /// Le serveur compte en POINTS DE CODE (`@MaxLength`, via
  /// `validator.isLength`) : un émoji y vaut un. Le compteur du champ, lui,
  /// compte des graphèmes, et un émoji nuancé (« 💪🏽 ») en fait un seul pour
  /// deux points de code. Compter les points de code ici dit la limite AVANT
  /// l'aller-retour, sans jamais laisser passer ce que le serveur refuserait.
  static String? _validateMessage(String? value) =>
      (value?.trim().runes.length ?? 0) > friendChallengeMessageMaxLength
      ? 'Ton mot dépasse $friendChallengeMessageMaxLength caractères.'
      : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Défier mes amis',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Titre du défi',
              controller: _title,
              hint: 'Qui court le plus ?',
              maxLength: 80,
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Donne un titre à ton défi.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            // Facultatif : lu par les seuls invités, sur l'écran du défi.
            // Jamais dans la notification, qui ne porte que le titre.
            AppTextField(
              label: 'Un mot pour tes amis (facultatif)',
              controller: _message,
              hint: 'On se motive ensemble ?',
              maxLines: 3,
              maxLength: friendChallengeMessageMaxLength,
              validator: _validateMessage,
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppSectionLabel('Ce qu’on compte'),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final metric in ChallengeMetric.values)
                  AppPill(
                    label: metric.label,
                    selected: metric == _metric,
                    selectedTone: AppPillTone.primary,
                    onTap: () => setState(() => _metric = metric),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppSectionLabel('Pendant combien de temps'),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final jours in friendChallengeDurations)
                  AppPill(
                    label: '$jours jours',
                    selected: jours == _duration,
                    selectedTone: AppPillTone.primary,
                    onTap: () => setState(() => _duration = jours),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppSectionLabel('Qui tu défies'),
            const SizedBox(height: AppSpacing.xxs),
            if (widget.friends.isEmpty)
              Text(
                'Tu n’as pas encore d’ami à défier. Ajoute quelqu’un depuis '
                'la communauté, et reviens.',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final ami in widget.friends)
                    AppPill(
                      label: ami.displayName,
                      selected: _invites.contains(ami.id),
                      selectedTone: AppPillTone.primary,
                      onTap: () => setState(() {
                        if (!_invites.remove(ami.id)) {
                          _invites.add(ami.id);
                        }
                      }),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Lancer le défi',
                onPressed: widget.friends.isEmpty ? null : _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

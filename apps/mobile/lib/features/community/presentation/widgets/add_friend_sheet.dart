import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Feuille « Ajouter un ami » : une adresse e-mail exacte, rien d'autre.
///
/// Rend l'adresse saisie, ou `null` si la personne renonce. La CONFIRMATION
/// est volontairement opaque (« si ce compte existe… ») : le serveur ne
/// révèle jamais qu'une adresse a un compte, l'interface non plus.
Future<String?> showAddFriendSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    // Navigateur RACINE : ouverte depuis un onglet, la feuille passerait
    // sinon SOUS la bottom bar flottante — qui masquerait son bouton.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: const _AddFriendForm(),
    ),
  );
}

class _AddFriendForm extends StatefulWidget {
  const _AddFriendForm();

  @override
  State<_AddFriendForm> createState() => _AddFriendFormState();
}

class _AddFriendFormState extends State<_AddFriendForm> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter un ami',
              style: AppTypography.subheading
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Son adresse exacte. Si ce compte existe, il recevra ta demande.',
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Adresse e-mail',
              controller: _controller,
              hint: 'ami@exemple.fr',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              prefixIcon: Icons.alternate_email_rounded,
              validator: (value) {
                final email = value?.trim() ?? '';
                // Garde-fou de FORME uniquement — la vérité est au serveur.
                if (email.isEmpty || !email.contains('@')) {
                  return 'Entre une adresse e-mail.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'Envoyer la demande', onPressed: _submit),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

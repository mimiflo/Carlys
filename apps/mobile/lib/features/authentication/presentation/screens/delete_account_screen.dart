import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/account_controllers.dart';
import '../widgets/account_deletion_summary.dart';
import '../widgets/auth_form_error.dart';
import '../widgets/auth_scaffold.dart';

/// Suppression du compte, exigée par Google Play et l'App Store : elle doit
/// se faire DANS l'application, pas par un e-mail au support.
///
/// Un écran plein, pas une feuille : ce qui disparaît et ce qui reste tient
/// en plusieurs phrases qu'il faut pouvoir lire sans se battre avec un
/// clavier. Le mot de passe EST la confirmation — pas de « tapez SUPPRIMER »
/// par-dessus, le serveur le réclame déjà et lui seul peut le vérifier.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    ref
        .read(deleteAccountControllerProvider.notifier)
        .submit(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountControllerProvider);
    final isLoading = state.isLoading;

    return AuthScaffold(
      title: 'Supprimer mon compte',
      subtitle:
          'C’est définitif : aucun retour en arrière, et aucun moyen de '
          'récupérer ce qui aura été effacé.',
      children: [
        const AccountDeletionSummary(),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: AppPasswordField(
            label: 'Ton mot de passe, pour confirmer',
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: (value) =>
                (value ?? '').isEmpty ? 'Le mot de passe est requis.' : null,
            // PAS d'`onFieldSubmitted` ici, contrairement au changement de
            // mot de passe : la touche « Termine » du clavier détruirait le
            // compte sans un seul appui délibéré sur le bouton rouge. La
            // révocation d'un simple appareil demande déjà une confirmation
            // explicite ; la suppression du compte ne peut pas en demander
            // moins.
            enabled: !isLoading,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.hasError) ...[
          AuthFormError(error: state.error!),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Supprimer définitivement',
          onPressed: _submit,
          isLoading: isLoading,
          variant: AppButtonVariant.destructive,
          isExpanded: true,
        ),
      ],
    );
  }
}

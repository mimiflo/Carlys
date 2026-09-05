import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/register_controller.dart';
import '../widgets/auth_form_error.dart';
import '../widgets/auth_scaffold.dart';

/// Création de compte. La validation d'e-mail est envoyée automatiquement ;
/// la session s'ouvre immédiatement (redirection par le routeur).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    ref
        .read(registerControllerProvider.notifier)
        .submit(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Aucune navigation impérative ici : l'ouverture de session fait avancer
    // le routeur (proposition Premium pendant le parcours de première
    // ouverture, accueil ensuite).
    final state = ref.watch(registerControllerProvider);
    final isLoading = state.isLoading;

    return AuthScaffold(
      title: 'Créer un compte',
      subtitle: 'Un e-mail de confirmation vous sera envoyé.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nom affiché',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: validateDisplayName,
                  enabled: !isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Adresse e-mail',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  validator: validateEmail,
                  enabled: !isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Mot de passe ($passwordMinLength caractères minimum)',
                  controller: _passwordController,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !isLoading,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.hasError) ...[
          AuthFormError(error: state.error!),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Créer mon compte',
          onPressed: _submit,
          isLoading: isLoading,
          isExpanded: true,
        ),
        const SizedBox(height: AppSpacing.md),
        // Sortie de secours : pendant le parcours de première ouverture,
        // cet écran s'impose — qui a déjà un compte doit pouvoir se
        // connecter d'ici.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Déjà un compte ?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: isLoading ? null : () => context.go(AppRoutes.login),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ],
    );
  }
}

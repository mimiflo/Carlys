import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/login_controller.dart';
import '../widgets/auth_form_error.dart';
import '../widgets/auth_scaffold.dart';

/// Connexion par e-mail. La redirection vers l'accueil est assurée par le
/// routeur dès que l'état de session devient authentifié.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    // Le contrôleur ignore les doubles soumissions via l'état loading.
    ref.read(loginControllerProvider.notifier).submit(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final isLoading = state.isLoading;

    return AuthScaffold(
      title: 'Connexion',
      subtitle: 'Content de vous revoir !',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  label: 'Mot de passe',
                  controller: _passwordController,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Le mot de passe est requis.'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                  enabled: !isLoading,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                isLoading ? null : () => context.push(AppRoutes.forgotPassword),
            child: const Text('Mot de passe oublié ?'),
          ),
        ),
        if (state.hasError) ...[
          AuthFormError(error: state.error!),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Se connecter',
          onPressed: _submit,
          isLoading: isLoading,
          isExpanded: true,
        ),
        const SizedBox(height: AppSpacing.md),
        // Wrap : passe à la ligne sur les écrans étroits ou avec une grande
        // taille de police système, au lieu de déborder.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Pas encore de compte ?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed:
                  isLoading ? null : () => context.push(AppRoutes.register),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ],
    );
  }
}

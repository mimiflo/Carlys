import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/validators/form_validators.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/forgot_password_controller.dart';
import '../widgets/auth_form_error.dart';
import '../widgets/auth_scaffold.dart';

/// Demande de réinitialisation. La réponse est identique que le compte
/// existe ou non (pas d'énumération d'adresses).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final isLoading = state.isLoading;
    final sent = state.valueOrNull == true;

    if (sent) {
      return AuthScaffold(
        title: 'E-mail envoyé',
        children: [
          const AppEmptyState(
            title: 'Vérifiez votre boîte de réception',
            message: 'Si un compte existe avec cette adresse, un e-mail de '
                'réinitialisation vient de lui être envoyé.',
            icon: Icons.mark_email_read_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Retour à la connexion',
            onPressed: () => context.pop(),
            variant: AppButtonVariant.secondary,
            isExpanded: true,
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Mot de passe oublié',
      subtitle:
          'Indiquez votre adresse e-mail : nous vous enverrons un lien de '
          'réinitialisation.',
      children: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Adresse e-mail',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            validator: validateEmail,
            onFieldSubmitted: (_) => _submit(),
            enabled: !isLoading,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.hasError) ...[
          AuthFormError(error: state.error!),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Envoyer le lien',
          onPressed: _submit,
          isLoading: isLoading,
          isExpanded: true,
        ),
      ],
    );
  }
}

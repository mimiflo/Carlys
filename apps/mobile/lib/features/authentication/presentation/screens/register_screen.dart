import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/register_controller.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_form_error.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_switch_prompt.dart';
import '../widgets/legal_consent_notice.dart';
import '../widgets/social_auth_buttons.dart';

/// Création de compte. La validation d'e-mail est envoyée automatiquement ;
/// la session s'ouvre immédiatement (redirection par le routeur).
///
/// Surface de MARQUE : le cœur de Carlys en décor haut-droit — là où la
/// maquette posait une sphère anonyme, c'est l'identité qui respire.
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
      title: 'Crée ton compte',
      subtitle:
          'Commence dès maintenant ton parcours vers une meilleure '
          'version de toi.',
      backdrop: const AuthBackdrop.heart(),
      brand: true,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Nom affiché',
                  inlineLabel: true,
                  prefixIcon: AppIcons.personOutline,
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: validateDisplayName,
                  enabled: !isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Adresse e-mail',
                  inlineLabel: true,
                  prefixIcon: AppIcons.mail,
                  // La vérité utile au moment utile : c'est à cette adresse
                  // que la confirmation partira.
                  helper: 'Un e-mail de confirmation te sera envoyé.',
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
                  inlineLabel: true,
                  prefixIcon: AppIcons.lock,
                  helper: 'Minimum $passwordMinLength caractères.',
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
        AppBrandButton(
          label: 'Créer mon compte',
          uppercase: false,
          trailingIcon: AppIcons.arrowForward,
          // Le violet de la maquette des écrans d'entrée, pas la signature.
          gradient: AppColors.cta,
          onPressed: _submit,
          isLoading: isLoading,
        ),
        const SizedBox(height: AppSpacing.lg),
        SocialAuthButtons(enabled: !isLoading),
        const SizedBox(height: AppSpacing.md),
        // Sous les boutons, pas au-dessus : on lit ce à quoi on consent au
        // moment où l'on s'apprête à appuyer.
        const LegalConsentNotice(),
        const SizedBox(height: AppSpacing.md),
        // Sortie de secours : pendant le parcours de première ouverture,
        // cet écran s'impose — qui a déjà un compte doit pouvoir se
        // connecter d'ici.
        AuthSwitchPrompt(
          prompt: 'Déjà un compte ?',
          actionLabel: 'Se connecter',
          onPressed: isLoading ? null : () => context.go(AppRoutes.login),
        ),
      ],
    );
  }
}

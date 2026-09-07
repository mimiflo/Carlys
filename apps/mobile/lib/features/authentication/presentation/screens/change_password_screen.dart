import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/validators/form_validators.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/account_controllers.dart';
import '../widgets/auth_form_error.dart';
import '../widgets/auth_scaffold.dart';

/// Changement de mot de passe depuis les réglages.
///
/// Le serveur révoque TOUTES les autres sessions au passage : c'est le geste
/// qui reprend la main sur un appareil perdu ou prêté. On le dit AVANT, pas
/// après — quelqu'un qui change son mot de passe pendant que son autre
/// téléphone synchronise doit savoir ce qui va s'y passer.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    ref
        .read(changePasswordControllerProvider.notifier)
        .submit(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
  }

  String? _validateConfirmation(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Confirme ton nouveau mot de passe.';
    }
    if (value != _newController.text) {
      return 'Les deux mots de passe diffèrent.';
    }
    return null;
  }

  String? _validateNew(String? value) {
    final error = validatePassword(value);
    if (error != null) return error;
    if (value == _currentController.text) {
      return 'Choisis un mot de passe différent de l’actuel.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    final isLoading = state.isLoading;

    if (state.valueOrNull == true) {
      return AuthScaffold(
        title: 'Mot de passe changé',
        children: [
          const AppEmptyState(
            icon: AppIcons.checkCircle,
            title: 'C’est fait',
            message:
                'Ton nouveau mot de passe est actif. Tes autres appareils ont '
                'été déconnectés : il faudra t’y reconnecter avec ce mot de '
                'passe. Celui-ci reste connecté.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Retour aux réglages',
            onPressed: () => context.pop(),
            variant: AppButtonVariant.secondary,
            isExpanded: true,
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Changer mon mot de passe',
      subtitle:
          'Au moins $passwordMinLength caractères. Tes autres appareils '
          'seront déconnectés.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPasswordField(
                  label: 'Mot de passe actuel',
                  controller: _currentController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Le mot de passe actuel est requis.'
                      : null,
                  enabled: !isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Nouveau mot de passe',
                  controller: _newController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validateNew,
                  enabled: !isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordField(
                  label: 'Confirme le nouveau mot de passe',
                  controller: _confirmController,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validateConfirmation,
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
          label: 'Changer mon mot de passe',
          onPressed: _submit,
          isLoading: isLoading,
          isExpanded: true,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/friend_code.dart';
import '../screens/friend_code_scanner_screen.dart';
import 'friend_code_card.dart';

/// Ce que la feuille « Ajouter un ami » rapporte : une adresse e-mail, ou
/// un code ami (tapé ou scanné) déjà ramené à sa forme canonique.
sealed class AddFriendInput {
  const AddFriendInput();
}

final class AddFriendByEmail extends AddFriendInput {
  const AddFriendByEmail(this.email);
  final String email;
}

final class AddFriendByCode extends AddFriendInput {
  const AddFriendByCode(this.code);
  final String code;
}

/// Feuille « Ajouter un ami » : mon QR à faire scanner, et UN champ qui
/// accepte l'un ou l'autre — l'arobase départage une adresse d'un code.
///
/// Rend `null` si la personne renonce. Pour un e-mail, la confirmation
/// reste opaque (« si ce compte existe… ») : le serveur ne révèle jamais
/// qu'une adresse a un compte, l'interface non plus. Un CODE, lui, se
/// partage volontairement : l'écran appelant confirme par le prénom.
Future<AddFriendInput?> showAddFriendSheet(BuildContext context) {
  return showAppSheet<AddFriendInput>(
    context,
    builder: (_) => const _AddFriendForm(),
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

  AddFriendInput? _parse(String raw) {
    final trimmed = raw.trim();
    if (looksLikeEmail(trimmed)) {
      return AddFriendByEmail(trimmed);
    }
    final code = normalizeFriendCode(trimmed);
    return code == null ? null : AddFriendByCode(code);
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_parse(_controller.text));
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FriendCodeScannerScreen()),
    );
    if (code != null && mounted) {
      Navigator.of(context).pop(AddFriendByCode(code));
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
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const FriendCodeCard(),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Son code ami, ou son adresse e-mail',
              controller: _controller,
              hint: 'AC23-DEF4 ou ami@exemple.fr',
              textInputAction: TextInputAction.done,
              autocorrect: false,
              prefixIcon: Icons.alternate_email_rounded,
              validator: (value) {
                // Garde-fou de FORME uniquement — la vérité est au serveur.
                return _parse(value ?? '') == null
                    ? 'Entre un code ami (XXXX-XXXX) ou une adresse e-mail.'
                    : null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'Envoyer la demande', onPressed: _submit),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Scanner son QR',
                icon: AppIcons.qrScan,
                variant: AppButtonVariant.secondary,
                onPressed: _scan,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

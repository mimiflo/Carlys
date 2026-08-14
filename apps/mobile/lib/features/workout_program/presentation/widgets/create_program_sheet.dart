import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Ce que la feuille de création rend : un nom et une ampleur en semaines.
class ProgramCreationDraft {
  const ProgramCreationDraft({required this.name, required this.weeksCount});

  final String name;
  final int weeksCount;
}

/// Feuille « Nouveau programme » : nom + nombre de semaines (1 à 52).
Future<ProgramCreationDraft?> showCreateProgramSheet(BuildContext context) {
  return showAppSheet<ProgramCreationDraft>(
    context,
    builder: (_) => const _CreateProgramForm(),
  );
}

class _CreateProgramForm extends StatefulWidget {
  const _CreateProgramForm();

  @override
  State<_CreateProgramForm> createState() => _CreateProgramFormState();
}

class _CreateProgramFormState extends State<_CreateProgramForm> {
  final _name = TextEditingController();
  final _weeks = TextEditingController(text: '4');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _weeks.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      ProgramCreationDraft(
        name: _name.text.trim(),
        weeksCount: int.parse(_weeks.text.trim()),
      ),
    );
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
              'Nouveau programme',
              style: AppTypography.subheading
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom',
              controller: _name,
              hint: 'Force en 4 semaines',
              textInputAction: TextInputAction.next,
              maxLength: 120,
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Nomme le programme.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Semaines (1 à 52)',
              controller: _weeks,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (value) {
                final weeks = int.tryParse(value?.trim() ?? '');
                if (weeks == null || weeks < 1 || weeks > 52) {
                  return 'Entre 1 et 52.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'Créer', onPressed: _submit),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

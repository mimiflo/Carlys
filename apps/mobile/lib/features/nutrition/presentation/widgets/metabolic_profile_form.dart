import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../controllers/nutrition_controllers.dart';

/// Formulaire du profil métabolique (sexe, naissance, taille, activité, but).
/// Le poids n'est PAS saisi ici : il provient des mesures corporelles.
class MetabolicProfileForm extends ConsumerStatefulWidget {
  const MetabolicProfileForm({required this.profile, super.key});

  final MetabolicProfile profile;

  @override
  ConsumerState<MetabolicProfileForm> createState() =>
      _MetabolicProfileFormState();
}

class _MetabolicProfileFormState extends ConsumerState<MetabolicProfileForm> {
  static const double _minHeightCm = 80;
  static const double _maxHeightCm = 250;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightController;

  late BiologicalSex? _sex = widget.profile.sex;
  late DateTime? _birthDate = widget.profile.birthDate;
  late ActivityLevel? _activityLevel = widget.profile.activityLevel;
  late NutritionGoal? _goal = widget.profile.goal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final height = widget.profile.heightCm;
    _heightController = TextEditingController(
      text: height == null ? '' : _formatHeight(height),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  static String _formatHeight(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1).replaceFirst('.', ',');

  double? _parsedHeight() {
    final raw = _heightController.text.trim().replaceFirst(',', '.');
    if (raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw);
  }

  bool get _weightMissing => widget.profile.weightKg == null;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (picked != null) {
      setState(
        () => _birthDate = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final update = MetabolicProfileUpdate(
      sex: _sex,
      birthDate: _birthDate,
      heightCm: _parsedHeight(),
      activityLevel: _activityLevel,
      goal: _goal,
    );
    if (update.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(nutritionActionsProvider).saveProfile(update);
    } on AppException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exception is NetworkException
                  ? 'Serveur injoignable : réessayez une fois connecté.'
                  : 'Enregistrement impossible. Vérifiez les valeurs saisies.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sexe biologique', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          SegmentedButton<BiologicalSex>(
            segments: [
              for (final sex in BiologicalSex.values)
                ButtonSegment(value: sex, label: Text(sex.label)),
            ],
            selected: {if (_sex != null) _sex!},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) => setState(
              () => _sex = selection.isEmpty ? _sex : selection.first,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Date de naissance', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          OutlinedButton.icon(
            onPressed: _pickBirthDate,
            icon: const Icon(Icons.cake_outlined),
            label: Text(
              _birthDate == null
                  ? 'Choisir une date'
                  : localizations.formatMediumDate(_birthDate!),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Taille (cm)',
            controller: _heightController,
            hint: 'Par exemple 178',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null; // Optionnel : le serveur liste les manquants.
              }
              final parsed = _parsedHeight();
              if (parsed == null ||
                  parsed < _minHeightCm ||
                  parsed > _maxHeightCm) {
                return 'Taille entre ${_minHeightCm.round()} et '
                    '${_maxHeightCm.round()} cm';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Niveau d’activité', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activityLevel,
            isExpanded: true,
            hint: const Text('Choisir un niveau'),
            items: [
              for (final level in ActivityLevel.values)
                DropdownMenuItem(
                  value: level,
                  child: Text(
                    '${level.label} : ${level.description}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _activityLevel = value),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Objectif', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          DropdownButtonFormField<NutritionGoal>(
            initialValue: _goal,
            isExpanded: true,
            hint: const Text('Choisir un objectif'),
            items: [
              for (final goal in NutritionGoal.values)
                DropdownMenuItem(value: goal, child: Text(goal.label)),
            ],
            onChanged: (value) => setState(() => _goal = value),
          ),
          if (_weightMissing) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: () => context.push(AppRoutes.progress),
              semanticLabel:
                  'Poids manquant : ajoutez une mesure depuis Progression',
              child: Row(
                children: [
                  Icon(
                    AppIcons.bodyMetrics,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Votre poids vient de vos mesures corporelles : '
                      'ajoutez-le depuis l’écran Progression.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Enregistrer mon profil',
            isExpanded: true,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

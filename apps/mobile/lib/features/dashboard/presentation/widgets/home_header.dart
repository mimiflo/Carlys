import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// En-tête de l'accueil : date du jour en mono, salutation en display,
/// avatar dégradé 44×44.
class HomeHeader extends StatelessWidget {
  const HomeHeader({required this.displayName, super.key});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
    final firstName = displayName?.split(' ').first;
    final initial = firstName == null || firstName.isEmpty
        ? '?'
        : firstName.characters.first.toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionLabel(date),
              const SizedBox(height: 10),
              Text(
                firstName == null ? 'Bonjour' : 'Bonjour,\n$firstName',
                style: AppTypography.display
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            borderRadius: AppRadius.avatarAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFF2B2B7A)],
            ),
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorderStrong),
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style:
                  AppTypography.subheading.copyWith(color: AppColors.neutral0),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import 'onboarding_option_card.dart';

/// Carte « Date de naissance » : ouvre le sélecteur de date et affiche la
/// valeur choisie.
class OnboardingBirthDateCard extends StatelessWidget {
  const OnboardingBirthDateCard({
    required this.birthDate,
    required this.onTap,
    super.key,
  });

  final DateTime? birthDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = birthDate;
    return OnboardingOptionCard(
      title: 'Date de naissance',
      subtitle: date == null
          ? 'Sert au calcul de ton âge'
          : 'Né(e) le ${_format(date)}',
      // Absente d'AppIcons : même glyphe que la maquette.
      icon: Icons.cake_rounded,
      selected: date != null,
      onTap: onTap,
    );
  }

  /// « 12 novembre 1998 » — jour puis mois/année du formateur commun.
  static String _format(DateTime date) =>
      '${formatThousands(date.day)} ${formatMonthYear(date)}';
}

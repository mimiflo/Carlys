import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/design_system.dart';

/// Coquille des 5 onglets : le contenu défile SOUS la bottom bar floutée
/// (`extendBody`), chaque onglet garde sa propre pile de navigation.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AppBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Re-taper l'onglet courant ramène à sa racine.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

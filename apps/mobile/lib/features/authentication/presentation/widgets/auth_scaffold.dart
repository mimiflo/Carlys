import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Gabarit commun des écrans d'authentification : centré, largeur bornée,
/// clavier et petits écrans gérés via le défilement.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: theme.textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

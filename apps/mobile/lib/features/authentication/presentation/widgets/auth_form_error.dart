import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';

/// Traduit une erreur du domaine en message utilisateur.
String authErrorMessage(Object error) {
  return switch (error) {
    NetworkException() =>
      'Connexion impossible. Vérifiez votre accès Internet.',
    UnauthorizedException(:final message) => message,
    ValidationException(:final message) => message,
    ServerException() => 'Le serveur est momentanément indisponible.',
    _ => 'Une erreur inattendue est survenue.',
  };
}

/// Bandeau d'erreur inline des formulaires d'authentification.
class AuthFormError extends StatelessWidget {
  const AuthFormError({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.1),
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          children: [
            Icon(AppIcons.error, size: 20, color: colorScheme.error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                authErrorMessage(error),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

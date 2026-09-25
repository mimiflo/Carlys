import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';

/// Traduit une erreur du domaine en message utilisateur.
///
/// Pour une erreur de validation, les messages PAR CHAMP l'emportent sur le
/// message général. L'API écrit des phrases destinées à un humain — « Adresse
/// e-mail invalide. », « Mot de passe trop court. » — et le client les range
/// déjà par champ ([ValidationException.fieldErrors]) ; seul l'affichage
/// manquait, si bien que l'écran ne montrait que le générique « Certaines
/// données sont invalides. », qui ne dit pas quoi corriger.
String authErrorMessage(Object error) {
  return switch (error) {
    NetworkException() => 'Connexion impossible. Vérifie ton accès Internet.',
    UnauthorizedException(:final message) => message,
    ValidationException(:final message, :final fieldErrors) =>
      fieldErrors.isEmpty ? message : fieldErrors.values.join('\n'),
    ServerException() => 'Le serveur est momentanément indisponible.',
    // Le serveur a accepté, l'appareil n'a pas pu passer à ce compte : la
    // session a été abandonnée (`LocalAccountEntry`), réessayer est sûr.
    AccountClaimException() =>
      'Ton compte n’a pas pu s’ouvrir sur ce téléphone. Réessaie dans un '
          'instant.',
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

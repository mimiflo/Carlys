/// Validateurs de formulaires — messages en français, alignés sur les
/// contraintes du serveur (packages/api-contracts).
library;

const int passwordMinLength = 10;
const int passwordMaxLength = 128;

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'L’adresse e-mail est requise.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Adresse e-mail invalide.';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Le mot de passe est requis.';
  }
  if (password.length < passwordMinLength) {
    return 'Au moins $passwordMinLength caractères.';
  }
  if (password.length > passwordMaxLength) {
    return 'Au plus $passwordMaxLength caractères.';
  }
  return null;
}

String? validateRequired(String? value, {String label = 'Ce champ'}) {
  if (value == null || value.trim().isEmpty) {
    return '$label est requis.';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Le nom affiché est requis.';
  }
  if (name.length > 60) {
    return 'Au plus 60 caractères.';
  }
  return null;
}

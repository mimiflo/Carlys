/// Préférence d'apparence de l'application.
enum AppThemeSetting {
  system('system', 'Système'),
  light('light', 'Clair'),
  dark('dark', 'Sombre'),
  oledDark('oled', 'Sombre OLED');

  const AppThemeSetting(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppThemeSetting fromStorage(String? value) =>
      AppThemeSetting.values.firstWhere(
        (setting) => setting.storageValue == value,
        orElse: () => AppThemeSetting.dark,
      );
}

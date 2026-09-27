/// Préférence d'apparence de l'application : Carlys est sombre, le seul
/// choix est la profondeur du fond.
///
/// Les thèmes « Clair » et « Système » ont été retirés (décision du
/// 27 septembre 2026). Une préférence enregistrée avant (`light`,
/// `system`), comme toute valeur inconnue, se lit « Sombre ».
enum AppThemeSetting {
  dark('dark', 'Sombre', 'Violet nuit'),
  oledDark('oled', 'Sombre OLED', 'Noir pur');

  const AppThemeSetting(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;

  /// Le fond que le thème peint, en deux mots.
  final String description;

  static AppThemeSetting fromStorage(String? value) =>
      AppThemeSetting.values.firstWhere(
        (setting) => setting.storageValue == value,
        orElse: () => AppThemeSetting.dark,
      );
}

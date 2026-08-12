/// Cadence adaptative des scènes animées.
///
/// Les scènes visent 30 i/s — le réglage historique du cœur. Sur un téléphone
/// qui peine à peindre une image, tenir cette cadence fait saccader TOUTE la
/// page, défilement compris : la scène monopolise le fil d'interface.
///
/// Plutôt qu'un réglage par appareil, la cadence suit la MESURE : le peintre
/// rapporte le coût de chaque image, et la scène ne peut occuper qu'une part
/// bornée du temps ([_maxDutyMicrosPerSecond]). Un appareil à l'aise reste à
/// 30 i/s pour toujours ; un appareil qui peine descend à 20 puis 15 i/s —
/// le mouvement reste, la page redevient fluide — et remonte s'il respire.
class SceneCadence {
  SceneCadence();

  /// Paliers, du plus fluide au plus économe.
  static const List<double> _steps = [30, 20, 15];

  /// Part de temps maximale accordée à la scène : 250 ms de peinture par
  /// seconde (un quart du fil d'interface). Au-delà, le reste de la page
  /// n'a plus le budget d'une image à 60 Hz.
  static const double _maxDutyMicrosPerSecond = 250000;

  /// Marge de remontée : on ne remonte que si le palier SUPÉRIEUR tiendrait
  /// franchement dans le budget, sinon la cadence oscillerait sans fin.
  static const double _recoveryFactor = 0.7;

  /// Images observées avant toute décision : la première image (caches
  /// froids) et les pics isolés (ramasse-miettes) ne comptent pas seuls.
  static const int _minSamples = 12;

  int _step = 0;
  double _averageMicros = 0;
  int _samples = 0;

  double get framesPerSecond => _steps[_step];

  /// Coût d'une image peinte, rapporté par le peintre de la scène.
  void reportPaintCost(Duration elapsed) {
    final micros = elapsed.inMicroseconds.toDouble();
    // Moyenne glissante exponentielle : lisse les pics sans traîner
    // des minutes de passé.
    _samples += 1;
    _averageMicros =
        _samples == 1 ? micros : _averageMicros * 0.9 + micros * 0.1;
    if (_samples < _minSamples) {
      return;
    }

    final duty = _averageMicros * framesPerSecond;
    if (duty > _maxDutyMicrosPerSecond && _step < _steps.length - 1) {
      _step += 1;
      _samples = 0; // La cadence vient de changer : la mesure repart.
      return;
    }
    if (_step > 0) {
      final higher = _steps[_step - 1];
      if (_averageMicros * higher < _maxDutyMicrosPerSecond * _recoveryFactor) {
        _step -= 1;
        _samples = 0;
      }
    }
  }
}

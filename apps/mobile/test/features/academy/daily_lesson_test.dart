import 'package:carlys_mobile/features/academy/domain/daily_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la question du jour change à MINUIT, une fois
/// par jour, sans jamais se répéter ni sauter.
///
/// Le défaut d'origine calculait une durée écoulée depuis le 1er janvier
/// (`now.difference(DateTime(now.year)).inDays`). Une durée ne compte pas les
/// jours quand l'heure change : au passage à l'heure d'été, l'heure perdue
/// faisait rendre la question de la veille le matin du changement, puis
/// décalait la bascule à 01 h 30 jusqu'à l'automne.
///
/// Les deux premiers tests ci-dessous sont écrits avec des `DateTime` LOCAUX,
/// exprès : sous un fuseau à changement d'heure, ils tombent avec l'ancien
/// calcul. C'est pourquoi les tests tournent sous `TZ=Europe/Paris`, imposé
/// par `scripts/check_mobile.sh` et par le bloc « Tests » de
/// `.github/workflows/mobile-ci.yml` — les runners sont en UTC, où l'heure ne
/// change jamais.
///
/// Sans ce fuseau, CE FICHIER NE GARDE RIEN. Mesuré en réintroduisant
/// l'ancien calcul : sous `TZ=UTC` les trois tests passent, bug compris —
/// le troisième y compris, car il ne franchit aucun changement d'heure et
/// rend donc le même quantième des deux façons. Sous `TZ=Europe/Paris`, les
/// deux premiers échouent. Le troisième ne distingue pas les deux calculs :
/// il fixe les valeurs exactes aux bornes (1er janvier, années bissextiles),
/// ce que les deux autres, écrits en écarts, ne voient pas.
void main() {
  test('deux instants du MÊME jour civil donnent le même rang', () {
    // Le 30 mars 2026 est le lendemain du passage à l'heure d'été en Europe.
    expect(
      dayOfYearIndex(DateTime(2026, 3, 30, 0, 30)),
      dayOfYearIndex(DateTime(2026, 3, 30, 23, 30)),
    );
  });

  test('deux jours consécutifs donnent des rangs consécutifs', () {
    // Enjambe le changement d'heure de printemps, puis celui d'automne.
    for (final veille in [
      DateTime(2026, 3, 29, 0, 30),
      DateTime(2026, 3, 30, 0, 30),
      DateTime(2026, 10, 24, 0, 30),
      DateTime(2026, 10, 25, 0, 30),
    ]) {
      final lendemain = DateTime(
        veille.year,
        veille.month,
        veille.day + 1,
        veille.hour,
        veille.minute,
      );
      expect(
        dayOfYearIndex(lendemain) - dayOfYearIndex(veille),
        1,
        reason: 'de $veille à $lendemain',
      );
    }
  });

  test('le rang est le quantième, zéro pour le 1er janvier', () {
    expect(dayOfYearIndex(DateTime(2026, 1, 1, 12)), 0);
    expect(dayOfYearIndex(DateTime(2026, 2, 1)), 31);
    expect(
      dayOfYearIndex(DateTime(2026, 3, 1)),
      59,
    ); // 2026 n'est pas bissextile
    expect(dayOfYearIndex(DateTime(2026, 12, 31)), 364);
    // 2028 l'est : février compte 29 jours, et l'année en compte 366.
    expect(dayOfYearIndex(DateTime(2028, 3, 1)), 60);
    expect(dayOfYearIndex(DateTime(2028, 12, 31)), 365);
  });
}

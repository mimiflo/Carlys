import 'package:carlys_mobile/features/academy/domain/academy_level.dart';
import 'package:carlys_mobile/features/academy/domain/academy_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les niveaux situent, ils ne notent pas — et surtout ils ne RECULENT
/// jamais : leurs seuils sont absolus, pas proportionnels au pack.
void main() {
  group('le barème', () {
    test('est strictement croissant, du rang comme du seuil', () {
      // Un barème désordonné ferait sauter des niveaux ou en rendrait
      // certains inatteignables, silencieusement.
      for (var i = 1; i < academyLevels.length; i++) {
        expect(academyLevels[i].seuil, greaterThan(academyLevels[i - 1].seuil));
        expect(academyLevels[i].rang, academyLevels[i - 1].rang + 1);
      }
      expect(academyLevels.first.rang, 1);
    });

    test('commence à la PREMIÈRE leçon, pas avant', () {
      expect(
        academyLevelOf(0),
        isNull,
        reason: 'Un « niveau zéro » d’office se lirait comme une note d’échec.',
      );
      expect(academyLevelOf(1)?.nom, 'Découverte');
    });

    test('chaque seuil ouvre exactement son niveau, pas le suivant', () {
      for (final niveau in academyLevels) {
        expect(academyLevelOf(niveau.seuil)?.rang, niveau.rang);
        expect(
          academyLevelOf(niveau.seuil - 1)?.rang ?? 0,
          niveau.rang - 1,
          reason: 'Une leçon avant le seuil, le niveau n’est pas encore là.',
        );
      }
    });

    test('ne redescend jamais quand la lecture avance', () {
      var precedent = 0;
      for (var abordees = 0; abordees <= 60; abordees++) {
        final rang = academyLevelOf(abordees)?.rang ?? 0;
        expect(rang, greaterThanOrEqualTo(precedent));
        precedent = rang;
      }
    });

    test('le prochain niveau est toujours le premier seuil non atteint', () {
      expect(nextAcademyLevelOf(0)?.nom, 'Découverte');
      expect(nextAcademyLevelOf(1)?.nom, 'Exploration');
      expect(nextAcademyLevelOf(12)?.nom, 'Profondeur');
      expect(
        nextAcademyLevelOf(30),
        isNull,
        reason: 'Au sommet, ne rien promettre de plus.',
      );
    });

    test('les seuils tiennent dans le pack ACTUEL : tous atteignables', () {
      // Le dernier seuil est absolu : si un dégraissage du pack passait
      // sous lui, « Érudition » deviendrait inatteignable sans bruit. Le
      // test du pack (academy_pack_test) compte les leçons réelles ; ici on
      // épingle seulement que le barème vise 30, une borne que le pack
      // dépasse largement (58 leçons à la fournée de septembre 2026).
      expect(academyLevels.last.seuil, 30);
    });
  });

  group('le pourcentage, une position qui nomme sa base', () {
    test('est TRONQUÉ : 100 ne se dit qu’au contenu réellement bouclé', () {
      const presque = DomainProgress(abordees: 53, total: 54);
      expect(presque.pourcent, 98);
      expect(presque.termine, isFalse);

      const boucle = DomainProgress(abordees: 54, total: 54);
      expect(boucle.pourcent, 100);

      // Le cas qui sépare la troncature de l'arrondi : 2/3 = 66,7. Un
      // arrondi dirait 67 — et surtout, à 199/200 il dirait « 100 % » d'un
      // contenu pas fini. C'est l'arrondi entier que ce test tue.
      const deuxTiers = DomainProgress(abordees: 2, total: 3);
      expect(deuxTiers.pourcent, 66);
      const presqueCent = DomainProgress(abordees: 199, total: 200);
      expect(presqueCent.pourcent, 99);
    });

    test('un contenu vide est à 0, jamais une division par zéro', () {
      const vide = DomainProgress(abordees: 0, total: 0);
      expect(vide.pourcent, 0);
      const packVide = AcademyProgress(abordees: 0, total: 0, parDomaine: {});
      expect(packVide.pourcent, 0);
    });

    test('le pack et le domaine comptent de la même façon', () {
      const pack = AcademyProgress(abordees: 24, total: 38, parDomaine: {});
      expect(pack.pourcent, 63);
      const domaine = DomainProgress(abordees: 3, total: 4);
      expect(domaine.pourcent, 75);
    });
  });
}

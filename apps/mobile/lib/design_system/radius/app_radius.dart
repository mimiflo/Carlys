import 'package:flutter/widgets.dart';

/// Rayons de bordure Carlys — refonte (tokens : radius.*).
abstract final class AppRadius {
  // Échelle générique
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;

  // Rayons sémantiques de la refonte
  static const double cardMain = 28;
  static const double cardSecondary = 24;
  static const double listRow = 22;
  static const double statTile = 20;
  static const double button = 18;
  static const double avatar = 16;
  static const double phoneFrame = 44;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));

  static const BorderRadius cardMainAll = BorderRadius.all(
    Radius.circular(cardMain),
  );
  static const BorderRadius cardSecondaryAll = BorderRadius.all(
    Radius.circular(cardSecondary),
  );
  static const BorderRadius listRowAll = BorderRadius.all(
    Radius.circular(listRow),
  );
  static const BorderRadius statTileAll = BorderRadius.all(
    Radius.circular(statTile),
  );
  static const BorderRadius buttonAll = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius avatarAll = BorderRadius.all(
    Radius.circular(avatar),
  );
}

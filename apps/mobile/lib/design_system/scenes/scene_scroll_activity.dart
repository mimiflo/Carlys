import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Coordination scènes ↔ défilement.
///
/// Chaque image du cœur (ou de l'hélice) coûte plusieurs millisecondes de
/// fil d'interface — précisément le budget qui manque PENDANT un défilement
/// sur un téléphone modeste : l'écran accrochait en haut de l'accueil, là où
/// la scène est visible, et redevenait parfaitement fluide plus bas. Pendant
/// que ça défile, les scènes se figent ; à l'arrêt, elles reprennent — on ne
/// regarde pas un battement pendant une pichenette.
///
/// À poser AUTOUR de la vue défilante d'un écran qui contient une scène.
/// Sans lui, les scènes animent en continu, comme avant.
class SceneScrollActivity extends StatefulWidget {
  const SceneScrollActivity({required this.child, super.key});

  final Widget child;

  /// Le signal « ça défile » de l'écran englobant, ou `null` hors portée.
  static ValueListenable<bool>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SceneScrollScope>()
      ?.scrolling;

  @override
  State<SceneScrollActivity> createState() => _SceneScrollActivityState();
}

class _SceneScrollActivityState extends State<SceneScrollActivity> {
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);

  /// Compteur de défilements EN COURS : un écran peut emboîter des vues
  /// défilantes (graphique horizontal dans une liste) — la scène ne reprend
  /// que quand plus rien ne bouge.
  int _active = 0;

  @override
  void dispose() {
    _scrolling.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _active += 1;
      _scrolling.value = true;
    } else if (notification is ScrollEndNotification) {
      _active = math.max(0, _active - 1);
      if (_active == 0) {
        _scrolling.value = false;
      }
    }
    return false; // On observe, on n'absorbe rien.
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: _SceneScrollScope(scrolling: _scrolling, child: widget.child),
    );
  }
}

class _SceneScrollScope extends InheritedWidget {
  const _SceneScrollScope({required this.scrolling, required super.child});

  final ValueNotifier<bool> scrolling;

  @override
  bool updateShouldNotify(_SceneScrollScope oldWidget) =>
      scrolling != oldWidget.scrolling;
}

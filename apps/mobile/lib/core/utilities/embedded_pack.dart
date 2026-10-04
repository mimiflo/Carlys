import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Un pack JSON EMBARQUÉ dans l'appli (leçons de l'Academy, recettes) : un
/// contenu éditorial qui s'ouvre hors ligne, lu une fois puis gardé.
///
/// C'est le RÉSULTAT qui est mémoïsé, jamais la future : une future ne
/// s'achève que dans la zone où elle est née, leçon apprise deux fois dans
/// ce dépôt (catalogue de démonstration, maillages animés).
class EmbeddedPack<T> {
  EmbeddedPack({
    required this.asset,
    required this.listKey,
    required this.parse,
    required this.emptyMessage,
  });

  final String asset;

  /// La clé de la liste dans le JSON (`lessons`, `recipes`).
  final String listKey;
  final T Function(Map<String, dynamic> json) parse;

  /// Un pack vide est une erreur de livraison, pas un état : il se dit.
  final String emptyMessage;

  List<T>? _items;
  Future<List<T>>? _loading;

  Future<List<T>> load() async {
    final cached = _items;
    if (cached != null) {
      return cached;
    }
    try {
      final items = await (_loading ??= _read());
      _items = items;
      return items;
    } finally {
      // Succès : le résultat est gardé. Échec : on ne mémoïse JAMAIS la
      // future en erreur, sinon tout rechargement (invalidation du
      // provider) rejouerait l'échec à jamais.
      _loading = null;
    }
  }

  Future<List<T>> _read() async {
    // `load` + `utf8.decode`, jamais `loadString` : au-delà de 50 Kio ce
    // dernier délègue le décodage à un isolat, qui ne s'achève pas sous
    // l'horloge simulée d'un test de widget.
    final data = await rootBundle.load(asset);
    final decoded =
        jsonDecode(utf8.decode(Uint8List.sublistView(data)))
            as Map<String, dynamic>;
    final items = (decoded[listKey] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(parse)
        .toList(growable: false);
    if (items.isEmpty) {
      throw FormatException(emptyMessage);
    }
    return items;
  }

  /// Réservé aux tests, qui vérifient le rechargement.
  void reset() {
    _items = null;
    _loading = null;
  }
}

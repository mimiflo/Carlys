import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Photos servies par le stockage objet, gardées sur l'appareil.
///
/// Pourquoi un cache écrit à la main plutôt qu'une bibliothèque : **l'URL d'un
/// média ne change jamais de contenu**. La clé de stockage porte l'identifiant
/// du média (`image/<uuid>.webp`) et le serveur répond `immutable` — remplacer
/// une photo, c'est déposer un AUTRE média, donc une autre URL. Un cache sans
/// invalidation est ici trivialement correct : quelques dizaines de lignes
/// suffisent, là où une dépendance apporterait tout un mécanisme d'expiration
/// dont on n'a aucun usage.
///
/// L'application est hors-ligne d'abord : sans cache, les photos
/// disparaîtraient dès la perte du réseau et seraient retéléchargées à chaque
/// démarrage à froid.
abstract interface class RemoteImageCache {
  /// Octets de l'image, ou `null` si elle est hors d'atteinte.
  ///
  /// Ne lève jamais : une photo absente n'est pas une panne, c'est un repli.
  Future<Uint8List?> bytesOf(String url);
}

/// Préfixe des images EMBARQUÉES, servies au mode démonstration.
///
/// La démo tourne sans serveur : ses vignettes voyagent dans l'application.
/// Leur donner ce schéma plutôt qu'un chemin nu évite toute ambiguïté — et
/// permet aux écrans de garder un seul et même chemin de code, qu'une image
/// vienne du réseau ou du paquet.
const String assetImageScheme = 'asset:';

class DiskRemoteImageCache implements RemoteImageCache {
  DiskRemoteImageCache({HttpClient? client}) : _injected = client;

  final HttpClient? _injected;

  /// Ouvert à la PREMIÈRE image réseau seulement : la démonstration ne sert
  /// que des images du paquet et n'a aucune raison d'ouvrir un client HTTP.
  HttpClient? _opened;

  HttpClient get _client => _injected ?? (_opened ??= HttpClient());

  /// Mémoire vive : évite de relire le disque à chaque défilement.
  final Map<String, Uint8List> _memory = {};

  /// Téléchargements en cours, partagés — une grille affiche la même photo
  /// plusieurs fois, et rien ne justifie de la chercher deux fois.
  final Map<String, Future<Uint8List?>> _inFlight = {};

  Directory? _directory;

  @override
  Future<Uint8List?> bytesOf(String url) {
    final cached = _memory[url];
    if (cached != null) return Future.value(cached);
    // Une image du paquet ne passe PAS par la file des téléchargements : elle
    // est locale, donc rien à mutualiser — et `rootBundle` peut répondre par
    // une future déjà résolue, qui achèverait `_fetch` avant même que la file
    // ait enregistré l'entrée.
    if (url.startsWith(assetImageScheme)) return _fromBundle(url);
    return _inFlight.putIfAbsent(url, () => _fetch(url));
  }

  Future<Uint8List?> _fromBundle(String url) async {
    try {
      final data =
          await rootBundle.load(url.substring(assetImageScheme.length));
      final bytes = data.buffer.asUint8List();
      _memory[url] = bytes;
      return bytes;
    } on Object {
      // Vignette absente du paquet : repli, comme une photo hors d'atteinte.
      return null;
    }
  }

  Future<Uint8List?> _fetch(String url) async {
    try {
      final file = await _fileFor(url);
      if (file != null && file.existsSync()) {
        final bytes = await file.readAsBytes();
        _memory[url] = bytes;
        return bytes;
      }

      final bytes = await _download(url);
      if (bytes == null) return null;
      _memory[url] = bytes;
      // L'écriture ne conditionne pas l'affichage : un disque plein ou un
      // dossier inaccessible dégrade le cache, il ne casse pas l'écran.
      if (file != null) {
        try {
          await file.writeAsBytes(bytes, flush: false);
        } on FileSystemException {
          // Sans cache disque, on retélécharge — c'est tout.
        }
      }
      return bytes;
    } on Object {
      return null;
    } finally {
      // La valeur retirée EST la future en cours : rien à attendre ici, on la
      // range dans une variable pour le dire explicitement.
      final Future<Uint8List?>? finished = _inFlight.remove(url);
      assert(finished != null, 'entrée retirée sans avoir été posée');
    }
  }

  Future<Uint8List?> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      // On draine quand même : une réponse non lue garde la connexion ouverte.
      await response.drain<void>();
      return null;
    }
    final chunks = <int>[];
    await for (final chunk in response) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  /// Fichier local d'une URL.
  ///
  /// Le nom est le dernier segment de l'URL — soit `<uuid>.<ext>`, déjà unique
  /// par construction — passé au tamis : seuls lettres, chiffres, tiret et
  /// point survivent. Une URL forgée ne peut donc pas écrire ailleurs que dans
  /// le dossier de cache, quoi qu'elle contienne.
  Future<File?> _fileFor(String url) async {
    final segment = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    final name = segment.replaceAll(RegExp(r'[^A-Za-z0-9.-]'), '');
    if (name.isEmpty || name.startsWith('.')) return null;
    try {
      final directory = _directory ??= await _ensureDirectory();
      return File('${directory.path}/$name');
    } on Object {
      return null;
    }
  }

  Future<Directory> _ensureDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/media');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

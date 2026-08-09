import 'dart:io';
import 'dart:typed_data';

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

class DiskRemoteImageCache implements RemoteImageCache {
  DiskRemoteImageCache({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

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
    return _inFlight.putIfAbsent(url, () => _fetch(url));
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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// FlutterSecureStorage en mémoire pour les tests (les méthodes non
/// utilisées passent par noSuchMethod).
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  /// Ce que `write` lève, quand le trousseau doit REFUSER d'enregistrer
  /// (keystore Android en vrac, matériel verrouillé). La lecture et
  /// l'effacement continuent de fonctionner.
  Object? failWrites;

  /// Ce que `read` lève, quand le trousseau est ILLISIBLE (clé perdue
  /// après une restauration, keystore occupé).
  Object? failReads;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final failure = failReads;
    if (failure != null) throw failure;
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final failure = failWrites;
    if (failure != null) throw failure;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

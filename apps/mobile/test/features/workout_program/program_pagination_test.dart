import 'dart:convert';

import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la liste des programmes ne s'arrête pas au
/// vingtième.
///
/// `GET /programs` est paginé par curseur au contrat comme au contrôleur, avec
/// une page de vingt par défaut, et l'enveloppe porte `meta.nextCursor` et
/// `meta.hasMore`. Ce client ne lisait ni l'un ni l'autre : au-delà de vingt
/// programmes, les suivants disparaissaient — sans erreur, sans message, sans
/// rien qui le laisse deviner. C'est la panne la plus coûteuse à
/// diagnostiquer : celle qui ressemble à un fonctionnement normal.

/// Une page servie par le faux serveur.
typedef Page = ({List<String> ids, String? nextCursor});

/// Adaptateur HTTP factice : sert les pages dans l'ordre et note les curseurs
/// reçus. Même motif que `community_repository_impl_test.dart`.
class _PagesAdapter implements HttpClientAdapter {
  _PagesAdapter(this.pages);

  final List<Page> pages;
  final List<String?> curseursRecus = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final cursor = options.queryParameters['cursor'] as String?;
    curseursRecus.add(cursor);
    final index = cursor == null
        ? 0
        : pages.indexWhere((page) => page.nextCursor == cursor) + 1;
    final page = pages[index.clamp(0, pages.length - 1)];
    return ResponseBody.fromString(
      jsonEncode({
        'data': [
          for (final id in page.ids)
            {
              'id': id,
              'name': 'Programme $id',
              'description': null,
              'weeksCount': 4,
              'isActive': false,
              'daysCount': 3,
              'updatedAt': '2026-09-15T10:00:00.000Z',
            },
        ],
        'meta': {
          'nextCursor': page.nextCursor,
          'hasMore': page.nextCursor != null,
        },
        'requestId': 'test',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({ProgramRepositoryImpl repository, _PagesAdapter adapter}) banc(
  List<Page> pages,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
  final adapter = _PagesAdapter(pages);
  dio.httpClientAdapter = adapter;
  return (repository: ProgramRepositoryImpl(dio), adapter: adapter);
}

void main() {
  test('suit le curseur jusqu’à la dernière page', () async {
    final b = banc([
      (ids: ['a', 'b'], nextCursor: 'curseur-1'),
      (ids: ['c', 'd'], nextCursor: 'curseur-2'),
      (ids: ['e'], nextCursor: null),
    ]);

    final programmes = await b.repository.list();

    expect(programmes.map((programme) => programme.id), [
      'a',
      'b',
      'c',
      'd',
      'e',
    ]);
    // Et les curseurs ont bien voyagé, dans l'ordre.
    expect(b.adapter.curseursRecus, [null, 'curseur-1', 'curseur-2']);
  });

  test('une page unique ne demande rien de plus', () async {
    // Contre-épreuve : la boucle ne doit pas redemander une page quand le
    // serveur a dit qu'il n'y en avait pas d'autre.
    final b = banc([
      (ids: ['seul'], nextCursor: null),
    ]);

    final programmes = await b.repository.list();

    expect(programmes, hasLength(1));
    expect(b.adapter.curseursRecus, [null]);
  });

  test('un serveur qui ne finit jamais est borné, pas infini', () async {
    // `hasMore` toujours vrai avec le même curseur : une boucle naïve ferait
    // tourner l'application sans fin. Le garde-fou coupe.
    final b = banc([
      (ids: ['x'], nextCursor: 'toujours-le-meme'),
    ]);

    final programmes = await b.repository.list();

    expect(b.adapter.curseursRecus.length, lessThanOrEqualTo(20));
    expect(programmes, isNotEmpty);
  });
}

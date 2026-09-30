import 'dart:convert';

/// Un évènement Server-Sent Events : son nom et sa donnée (texte brut).
typedef SseEvent = ({String event, String data});

/// Les évènements SSE d'un corps de réponse, au fil de leur arrivée.
///
/// Ne lit que ce que l'API Carlys écrit (`event:` puis `data:`, une ligne
/// vide pour finir) : ni `id:`, ni `retry:`, ignorés comme le prévoit la
/// norme. Un évènement sans nom vaut `message`.
Stream<SseEvent> sseEvents(Stream<List<int>> bytes) async* {
  var event = 'message';
  final data = StringBuffer();
  final lines = utf8.decoder.bind(bytes).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield (event: event, data: data.toString());
      event = 'message';
      data.clear();
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      if (data.isNotEmpty) data.write('\n');
      data.write(line.substring(5).trimLeft());
    }
  }
}

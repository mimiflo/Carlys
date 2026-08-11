/// Chargement du pack d'apprentissage embarqué (`assets/academy/pack.json`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/entities/academy.dart';

/// C'est le RÉSULTAT qui est mémoïsé, jamais la future : une future ne
/// s'achève que dans la zone où elle est née — leçon apprise deux fois dans
/// ce dépôt (catalogue de démonstration, maillages animés).
List<Lesson>? _lessons;
Future<List<Lesson>>? _loading;

Future<List<Lesson>> loadAcademyPack() async {
  final cached = _lessons;
  if (cached != null) {
    return cached;
  }
  final lessons = await (_loading ??= _read());
  _lessons = lessons;
  _loading = null;
  return lessons;
}

Future<List<Lesson>> _read() async {
  // `load` + `utf8.decode`, jamais `loadString` : au-delà de 50 Kio ce
  // dernier délègue le décodage à un isolat, qui ne s'achève pas sous
  // l'horloge simulée d'un test de widget.
  final data = await rootBundle.load('assets/academy/pack.json');
  final raw = utf8.decode(Uint8List.sublistView(data));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final lessons = (decoded['lessons'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(_lesson)
      .toList(growable: false);
  if (lessons.isEmpty) {
    throw const FormatException('pack d’apprentissage vide');
  }
  return lessons;
}

Lesson _lesson(Map<String, dynamic> json) {
  final question = json['question'] as Map<String, dynamic>;
  final choices = (question['choices'] as List<dynamic>)
      .cast<String>()
      .toList(growable: false);
  final answerIndex = question['answerIndex'] as int;
  if (answerIndex < 0 || answerIndex >= choices.length) {
    throw FormatException('réponse hors bornes pour ${json['id']}');
  }
  return Lesson(
    id: json['id'] as String,
    category: AcademyCategory.values.byName(json['category'] as String),
    title: json['title'] as String,
    body: json['body'] as String,
    question: QuizQuestion(
      prompt: question['prompt'] as String,
      choices: choices,
      answerIndex: answerIndex,
      explanation: question['explanation'] as String,
    ),
  );
}

/// Réservé aux tests, qui vérifient le rechargement.
void resetAcademyPackCache() {
  _lessons = null;
  _loading = null;
}

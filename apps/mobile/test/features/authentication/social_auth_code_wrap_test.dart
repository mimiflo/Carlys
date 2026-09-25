import 'dart:io';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_sign_in_unavailable.dart';
import 'package:carlys_mobile/features/authentication/presentation/utils/social_auth_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// LA LIGNE DU CODE SE RECOPIE D'UN SEUL TENANT, même à 320 points et texte
/// agrandi deux fois.
///
/// Le défaut : `Code : google-failed_to_recover_auth` s'affichait en
/// « Code : google- » / « failed_to_reco » / « ver_auth ». Le moteur de
/// texte coupe après un tiret, jamais après un souligné : faute de place, il
/// tranchait au caractère, sans marque, et le testeur recopiait un code
/// faux.
///
/// Mesuré avec les VRAIES fontes du bundle : le harnais dessine sinon des
/// glyphes carrés, bien plus larges que JetBrains Mono, et les coupures
/// n'auraient rien à voir avec celles d'un téléphone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // La première fonte chargée sert pour toutes les graisses : la
    // régulière, celle de la ligne du code et du message.
    for (final (family, file) in const [
      ('Inter', 'Inter-Regular.ttf'),
      ('JetBrainsMono', 'JetBrainsMono-Regular.ttf'),
    ]) {
      final bytes = File('assets/fonts/$file').readAsBytes();
      await (FontLoader(
        family,
      )..addFont(bytes.then(ByteData.sublistView))).load();
    }
  });

  late BuildContext screen;

  Future<void> pumpNarrow(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(640, 1136);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              screen = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  /// Les lignes de la ligne du code, telles que le moteur les a posées :
  /// chaque signe est rangé sous le haut de sa boîte.
  List<String> linesOf(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );
    final lines = <double, StringBuffer>{};
    for (var i = 0; i < text.length; i++) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      lines.putIfAbsent(boxes.first.top, StringBuffer.new).write(text[i]);
    }
    final tops = lines.keys.toList()..sort();
    return [for (final top in tops) lines[top].toString()];
  }

  final alnum = RegExp('[A-Za-z0-9]');

  for (final failure in [
    for (final code in [
      'google-failed_to_recover_auth',
      'google-user_recoverable_auth',
      'google-sign_in_failed',
      'google-network_error',
      'google-java-illegal-state',
      'reseau-certificat',
    ])
      describeSocialFailure(
        SocialProvider.google,
        SocialSignInUnavailable(
          SocialProvider.google,
          SocialSignInObstacle.echec,
          code: code,
        ),
      ),
    describeSocialFailure(
      SocialProvider.google,
      const ServerException(
        'x',
        statusCode: 500,
        requestId: '1a2b3c4d-9e8f-4a5b-8c7d-0123456789ab',
      ),
    ),
    describeSocialFailure(
      SocialProvider.google,
      const MalformedResponseException('x', requestId: '0badc0de-1234'),
    ),
  ]) {
    testWidgets('${failure.code} : jamais coupé au milieu d’un morceau', (
      tester,
    ) async {
      await pumpNarrow(tester);
      AppNotices.of(screen).show(
        failure.message,
        tone: AppNoticeTone.error,
        detail: failure.codeLine,
        detailSemanticsLabel: failure.spokenCodeLine,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final text = failure.codeLine;
      final lines = linesOf(tester, text);
      // Chaque coupure tombe ENTRE deux morceaux : jamais une lettre ou un
      // chiffre de part et d'autre.
      for (var k = 1; k < lines.length; k++) {
        final before = lines[k - 1].replaceAll('​', '');
        final after = lines[k].replaceAll('​', '');
        expect(
          before.isNotEmpty &&
              after.isNotEmpty &&
              alnum.hasMatch(before[before.length - 1]) &&
              alnum.hasMatch(after[0]),
          isFalse,
          reason: 'coupé au milieu d’un morceau : $lines',
        );
      }
      // La référence reste soudée à « réf. », d'un seul tenant.
      final ref = failure.reference;
      if (ref != null) {
        expect(
          lines.where((line) => line.contains('réf. $ref')),
          hasLength(1),
          reason: 'référence coupée : $lines',
        );
      }
    });
  }
}

/// La DIRECTION des dépendances entre couches, que rien ne tenait.
///
/// Mesuré avant d'écrire ce fichier, sur des violations qui COMPILENT et
/// dont les symboles servent vraiment — une entité de `domain` important à
/// la fois `data` et `presentation`, un dépôt de `data` important un écran :
/// `flutter analyze` rend 0, « No issues found! », et la suite passe, 629
/// verts pour 2 rouges, les deux venant d'ici. Ni l'analyseur, ni le lint,
/// ni aucun hook ne connaissent la notion de couche : c'est une convention
/// de dossiers, et une convention que rien ne relit n'est qu'un souvenir.
///
/// Le widget qui appelle `Dio()` dans son `build()` mérite une nuance
/// honnête : `flutter analyze` reste à 0, mais 4 tests de widget tombent —
/// non parce qu'ils comprennent les couches, seulement parce que l'appel
/// réseau échoue pendant qu'ils montent l'écran. Un widget qui TIENDRAIT
/// Dio sans l'appeler au montage ne serait vu de personne. Détection par
/// effet de bord n'est pas garde-fou.
///
/// Le code, lui, la respecte déjà partout : ce filet naît donc vert, et son
/// travail est de le garder vert.
///
/// ── Ce qui est VOLONTAIREMENT hors du filet ────────────────────────────
///
/// 1. Les arêtes ENTRE fonctionnalités. `lib/features/README.md` en
///    documente 6 ; il en existe 137, réparties sur 46 arêtes, avec 4
///    cycles. Une liste blanche naîtrait donc rouge, et un filet qui naît
///    rouge est une dette, pas un filet. La documentation est reprise
///    ailleurs ; l'assertion viendra après, sur une base honnête.
///
/// 2. `presentation` → `data`. Il en existe 31, dont 29 dans
///    `presentation/controllers/` : c'est le câblage Riverpod, un contrôleur
///    doit bien nommer l'implémentation qu'il fournit au provider. Les 2
///    autres (`push_foreground_host.dart`, `exercise_picker_sheet.dart`)
///    vont chercher un provider, pas un client HTTP. Interdire l'arête
///    entière punirait le câblage ; c'est donc le TRANSPORT qui est
///    interdit dans les widgets, ci-dessous, et c'est lui qui compte.
///
/// 3. `lib/core/`. Un contrôleur qui importe `core/api/dio_client.dart` pour
///    fournir un provider reste légitime (2 fichiers le font). Seuls les
///    écrans et widgets se voient interdire `core/api/` et `core/database/`.
///
/// 4. L'usage sans import : la lecture est textuelle, donc un symbole atteint
///    par une chaîne d'`export` échappe au comptage.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/dart_imports.dart';

/// Les trois couches de la structure feature-first.
const Set<String> _layers = {'domain', 'data', 'presentation'};

/// Sous-dossiers de `presentation/` qui dessinent l'écran, par opposition à
/// ceux qui le câblent (`controllers/`, `providers/`).
const Set<String> _uiFolders = {'widgets', 'screens', 'utils'};

/// La couche d'un chemin `lib/features/<fonctionnalité>/<couche>/…`, ou
/// `null` si le chemin est ailleurs (`lib/core/`, `lib/design_system/`…).
String? _layerOf(String? path) {
  if (path == null) return null;
  final parts = p.posix.split(path);
  if (parts.length < 5) return null;
  if (parts[0] != 'lib' || parts[1] != 'features') return null;
  return _layers.contains(parts[3]) ? parts[3] : null;
}

/// Le sous-dossier de `presentation/` d'un chemin, ou `null`.
String? _presentationFolderOf(String path) {
  final parts = p.posix.split(path);
  if (parts.length < 6) return null;
  if (parts[0] != 'lib' || parts[1] != 'features') return null;
  return parts[3] == 'presentation' ? parts[4] : null;
}

/// Un échec qui se lit sans ouvrir de débogueur : chaque ligne nomme le
/// fichier, la ligne et la cible.
String _report(String rule, List<String> offenders) {
  return '$rule\n  - ${offenders.join('\n  - ')}';
}

/// Les fautifs sous forme de texte : la liste affichée par le matcher reste
/// alors lisible telle quelle, sans nom de classe parasite.
List<String> _cite(Iterable<DartImport> offenders) =>
    offenders.map((offender) => offender.toString()).toList();

void main() {
  late List<DartImport> imports;

  setUpAll(() {
    // `flutter test` s'exécute depuis la racine du paquet (apps/mobile).
    imports = readDartImports('lib/features');
  });

  test('le filet lit vraiment les sources', () {
    // Sans cette assertion, une expression régulière cassée ou un
    // déplacement de `lib/features/` rendrait les quatre règles suivantes
    // vertes en ne lisant plus rien : le pire état pour un garde-fou, celui
    // où il rassure sans regarder. Le seuil est volontairement bas — il ne
    // mesure pas la taille du projet, il détecte l'aveuglement.
    expect(
      imports,
      hasLength(greaterThan(500)),
      reason:
          'Seulement ${imports.length} directives lues sous lib/features : '
          'la lecture est probablement cassée.',
    );
    final scanned = imports.map((i) => _layerOf(i.file)).toSet();
    expect(scanned, containsAll(_layers));
  });

  test('le domaine ne connaît ni les données ni l’interface', () {
    final offenders = _cite(
      imports
          .where((i) => _layerOf(i.file) == 'domain')
          .where(
            (i) => const {'data', 'presentation'}.contains(_layerOf(i.target)),
          )
          .toList(),
    );

    expect(
      offenders,
      isEmpty,
      reason: _report(
        'Le domaine porte les règles métier : il doit pouvoir se lire, se '
        'tester et se déplacer sans rien savoir de Dio, de Drift ni de '
        'Flutter. Un domaine qui importe `data` ou `presentation` inverse '
        'la dépendance et rend ses règles intestables seules.',
        offenders,
      ),
    );
  });

  test('les données ne connaissent pas l’interface', () {
    final offenders = _cite(
      imports
          .where((i) => _layerOf(i.file) == 'data')
          .where((i) => _layerOf(i.target) == 'presentation')
          .toList(),
    );

    expect(
      offenders,
      isEmpty,
      reason: _report(
        'Un dépôt, un mapper ou une source de données qui importe un écran '
        'ne peut plus être réutilisé ni testé sans monter un widget.',
        offenders,
      ),
    );
  });

  test('aucun client HTTP hors de la couche data', () {
    const clients = ['package:dio', 'package:http/'];
    final offenders = _cite(
      imports
          .where((i) => clients.any(i.uri.startsWith))
          .where((i) => _layerOf(i.file) != 'data')
          .toList(),
    );

    expect(
      offenders,
      isEmpty,
      reason: _report(
        'Le transport HTTP appartient à `data/`. Ailleurs, il court-circuite '
        'le chemin contrôleur → use case → dépôt, et avec lui la gestion '
        'des erreurs, le rafraîchissement du jeton et le mode hors ligne.',
        offenders,
      ),
    );
  });

  test('aucun écran ni widget ne touche au transport ni à la base', () {
    // La règle « jamais d'appel API depuis un widget » prise au pied de la
    // lettre : ce qui est interdit, c'est de tenir le CLIENT (Dio, Drift) ou
    // ce qui le fabrique, pas de nommer un provider.
    const forbidden = [
      'package:dio',
      'package:http/',
      'package:drift/',
      'core/api/',
      'core/database/',
      'data/datasources/',
    ];
    final offenders = _cite(
      imports
          .where((i) => _uiFolders.contains(_presentationFolderOf(i.file)))
          .where(
            (i) => forbidden.any(
              (needle) =>
                  i.uri.startsWith(needle) || i.uri.contains('/$needle'),
            ),
          )
          .toList(),
    );

    expect(
      offenders,
      isEmpty,
      reason: _report(
        'Un écran ou un widget qui tient un client HTTP, la base Drift ou '
        'une source de données distante contourne le chemin contrôleur → '
        'use case → dépôt : plus d’état de chargement, plus d’état d’erreur, '
        'plus de file hors ligne. Passer par un provider de contrôleur.',
        offenders,
      ),
    );
  });
}

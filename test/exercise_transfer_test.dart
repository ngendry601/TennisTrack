import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/screens/seance/exercise_library_screen.dart';
import 'package:tennis_track/services/session_store.dart';
import 'package:tennis_track/utils/exercise_transfer.dart';

/// PNG valide de 1 × 1 pixel.
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

String _imagesFile(List<Map<String, Object?>> images) => jsonEncode({
      'format': kImagesImportFormat,
      'version': 1,
      'images': images,
    });

Map<String, Object?> _entry(int? id, String nom) => {
      'exercice_id': id,
      'nom': nom,
      'image_base64': base64Encode(_png),
    };

void main() {
  const service = TrainingCategory(id: 1, nom: 'Service');
  const rouge = BallColor(id: 1, nom: 'Rouge');

  group('export de la liste', () {
    test('contient les champs utiles, sans les images', () {
      final json = exportExercisesJson([
        Exercise(
          id: 4,
          name: 'Plot et pastille',
          pointsToWork: 'Replacement',
          execution: 'Toucher un plot',
          durationMinutes: 15,
          image: _png,
          categories: const [service],
          ballColors: const [rouge],
        ),
      ]);
      final data = jsonDecode(json) as Map<String, Object?>;

      expect(data['format'], kExercisesExportFormat);
      expect(data['exercices'], [
        {
          'id': 4,
          'nom': 'Plot et pastille',
          'points_travailles': 'Replacement',
          'deroulement': 'Toucher un plot',
          'duree_minutes': 15,
          'themes': ['Service'],
          'couleurs_balle': ['Rouge'],
          'a_une_image': true,
        },
      ]);
      expect(json, isNot(contains(base64Encode(_png))));
    });
  });

  group('lecture du fichier d’images', () {
    test('lit les images PNG', () {
      final images = parseImagesJson(_imagesFile([_entry(4, 'Plot')]));
      expect(images.single.exerciseId, 4);
      expect(images.single.name, 'Plot');
      expect(images.single.bytes, _png);
    });

    test('refuse un fichier invalide', () {
      expect(() => parseImagesJson('pas du json'),
          throwsA(isA<ImageImportException>()));
      expect(() => parseImagesJson(jsonEncode({'format': 'autre'})),
          throwsA(isA<ImageImportException>()));
      expect(
        () => parseImagesJson(jsonEncode({
          'format': kImagesImportFormat,
          'version': 99,
          'images': [],
        })),
        throwsA(isA<ImageImportException>()),
      );
      expect(
        () => parseImagesJson(_imagesFile([
          {
            'exercice_id': 1,
            'nom': 'Texte',
            'image_base64': base64Encode(utf8.encode('pas une image')),
          },
        ])),
        throwsA(isA<ImageImportException>()),
      );
    });
  });

  group('association aux exercices', () {
    final exercises = [
      const Exercise(id: 1, name: 'Plot et pastille'),
      Exercise(id: 2, name: 'Replacement opposé', image: _png),
      const Exercise(id: 3, name: 'Doublon'),
      const Exercise(id: 4, name: 'doublon '),
    ];

    ImportedImage imported(int? id, String name) =>
        ImportedImage(exerciseId: id, name: name, bytes: _png);

    test('par id et nom, puis par nom seul', () {
      final plan = planImageImport(exercises, [
        imported(1, 'Plot et pastille'),
        // Id différent (appli réinstallée) : retrouvé par le nom.
        imported(42, '  replacement   OPPOSÉ '),
      ]);
      expect(plan.images.keys, unorderedEquals([1, 2]));
      expect(plan.replaced, 1);
      expect(plan.notFound, isEmpty);
    });

    test('ignore les images sans correspondance sûre', () {
      final plan = planImageImport(exercises, [
        // Id existant mais nom différent : jamais appliqué à l'aveugle.
        imported(1, 'Autre exercice'),
        // Deux exercices portent ce nom.
        imported(null, 'Doublon'),
      ]);
      expect(plan.images, isEmpty);
      expect(plan.notFound, ['Autre exercice', 'Doublon']);
    });

    test('un nom en double reste retrouvé grâce à son id', () {
      final plan = planImageImport(exercises, [imported(4, 'Doublon')]);
      expect(plan.images.keys, [4]);
    });
  });

  group('avec la base', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Database db;
    late TennisRepository repository;

    setUp(() async {
      db = await openAppDatabase(path: inMemoryDatabasePath);
      repository = TennisRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('enregistre les images sans toucher au reste', () async {
      final id = await repository.insertExercise(const Exercise(
        id: 0,
        name: 'Plot',
        execution: 'Déroulement',
        categories: [service],
      ));

      await repository.updateExerciseImages({id: _png});

      final saved = (await repository.getExercises()).single;
      expect(saved.image, _png);
      expect(saved.execution, 'Déroulement');
      expect(saved.categories.map((c) => c.nom), ['Service']);
    });

    testWidgets('importe le fichier depuis l’onglet Exercices', (tester) async {
      final store = SessionStore(repository: repository);
      late int id;
      await tester.runAsync(() async {
        await store.load();
        id = (await store
                .saveExercise(const Exercise(id: 0, name: 'Plot et pastille')))
            .id;
      });

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: ExerciseLibraryScreen(
            store: store,
            pickImportFile: () async => Uint8List.fromList(utf8.encode(
                _imagesFile(
                    [_entry(id, 'Plot et pastille'), _entry(99, 'Inconnu')]))),
          ),
        ),
      ));

      await tester.tap(find.byTooltip('Schémas des exercices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer les images'));
      await tester.pumpAndSettle();

      expect(
          find.text('1 image à ajouter à tes exercices.\n\n'
              'Exercice introuvable (ignoré) : « Inconnu ».'),
          findsOneWidget);

      await tester.tap(find.text('Importer'));
      // SQLite (ffi) répond hors de l'horloge simulée du test : on alterne
      // vraie attente et reconstruction jusqu'à la fin de l'écriture.
      for (var i = 0; i < 200 && store.exercises.single.image == null; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(store.exercises.single.image, _png);
      expect(find.text('1 image importée.'), findsOneWidget);
    });
  });
}

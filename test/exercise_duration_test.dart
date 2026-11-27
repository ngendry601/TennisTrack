import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/screens/seance/exercise_form_screen.dart';
import 'package:tennis_track/screens/session/session_detail_screen.dart';
import 'package:tennis_track/services/session_store.dart';
import 'package:tennis_track/utils/exercise_durations.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );

void main() {
  group('total des exercices', () {
    const quinze = Exercise(id: 1, name: 'A', durationMinutes: 15);
    const cinquante = Exercise(id: 2, name: 'B', durationMinutes: 55);
    const sansDuree = Exercise(id: 3, name: 'C');

    test('additionne les durées renseignées', () {
      expect(exercisesTotalMinutes([quinze, cinquante, sansDuree]), 70);
      expect(exercisesTotalLabel([quinze, cinquante], 90),
          'Exercices : 1h10min sur 1h30min');
    });

    test('signale un dépassement et les exercices sans durée', () {
      expect(exercisesTotalLabel([quinze, cinquante, sansDuree], 60),
          'Exercices : 1h10min sur 1h · dépasse de 10min · 1 sans durée');
    });

    test('rien à afficher sans aucune durée', () {
      expect(exercisesTotalLabel([sansDuree], 60), isNull);
      expect(exercisesTotalLabel([], 60), isNull);
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

    test('enregistre, modifie et efface la durée', () async {
      final id = await repository.insertExercise(
          const Exercise(id: 0, name: 'Panier', durationMinutes: 20));
      expect((await repository.getExercises()).single.durationMinutes, 20);

      await repository.updateExercise(
          const Exercise(id: 0, name: 'Panier').copyWith(id: id));
      expect((await repository.getExercises()).single.durationMinutes, isNull);
    });

    test('refuse une durée nulle ou négative', () async {
      expect(
        () => db.insert('exercice', {'nom': 'X', 'duree_minutes': 0}),
        throwsA(isA<DatabaseException>()),
      );
    });

    testWidgets('la fiche d’exercice enregistre la durée', (tester) async {
      final store = SessionStore(repository: repository);
      await tester.runAsync(store.load);

      await tester.pumpWidget(_app(ExerciseFormScreen(store: store)));
      await tester.enterText(
          find.widgetWithText(TextField, 'Nom de l’exercice'), 'Panier');
      await tester.enterText(
          find.widgetWithText(TextField, 'Durée (facultatif)'), '75');
      await tester.pump();
      expect(find.text('1h15min'), findsOneWidget);

      await tester.tap(find.text(store.categories.first.nom));
      await tester.tap(find.text(store.ballColors.first.nom));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Valider l’exercice'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Valider l’exercice'));
      for (var i = 0; i < 200 && store.exercises.isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }

      expect(store.exercises.single.durationMinutes, 75);
    });

    testWidgets('les détails d’une séance affichent le total', (tester) async {
      final store = SessionStore(repository: repository);
      await tester.runAsync(() async {
        await store.load();
        final panier = await store.saveExercise(
            const Exercise(id: 0, name: 'Panier', durationMinutes: 15));
        final match = await store.saveExercise(
            const Exercise(id: 0, name: 'Match', durationMinutes: 30));
        await store.upsert(TrainingSession(
          id: 0,
          date: DateTime(2026, 11, 24),
          durationMinutes: 60,
          intensity: 3,
          ballColor: store.ballColors.first,
          categories: [store.categories.first],
          exercises: [panier, match],
        ));
      });

      await tester.pumpWidget(_app(SessionDetailScreen(
        store: store,
        session: store.sessions.single,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Exercices : 45min sur 1h'), findsOneWidget);
      expect(find.text('15min'), findsOneWidget);
      expect(find.text('30min'), findsOneWidget);
    });
  });

  test('migration v5 -> v6 : les exercices existants n’ont pas de durée',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('tennistrack_v5');
    final path = p.join(directory.path, 'v5.db');

    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (database, version) async {
            for (final sql in const [
              "CREATE TABLE exercice (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL, points_travailles TEXT NOT NULL DEFAULT '', deroulement TEXT NOT NULL DEFAULT '', image BLOB)",
              'CREATE TABLE categorie (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL UNIQUE)',
              'CREATE TABLE seance (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, duree_minutes INTEGER NOT NULL, intensite INTEGER NOT NULL, couleur_balle_id INTEGER NOT NULL, heure_debut TEXT)',
              'CREATE TABLE couleur_balle (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL UNIQUE)',
              'CREATE TABLE exercice_categorie (exercice_id INTEGER NOT NULL, categorie_id INTEGER NOT NULL, PRIMARY KEY (exercice_id, categorie_id))',
              'CREATE TABLE exercice_couleur_balle (exercice_id INTEGER NOT NULL, couleur_balle_id INTEGER NOT NULL, PRIMARY KEY (exercice_id, couleur_balle_id))',
              "INSERT INTO exercice (nom, points_travailles) VALUES ('Panier', 'Lancer')",
            ]) {
              await database.execute(sql);
            }
          },
        ));
    await old.close();

    final migrated = await openAppDatabase(path: path);
    final exercises = await TennisRepository(migrated).getExercises();

    expect(await migrated.getVersion(), kDatabaseVersion);
    expect(exercises.single.name, 'Panier');
    expect(exercises.single.pointsToWork, 'Lancer');
    expect(exercises.single.durationMinutes, isNull);

    await migrated.close();
    await directory.delete(recursive: true);
  });
}

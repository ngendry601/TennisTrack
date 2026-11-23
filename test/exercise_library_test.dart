import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/screens/seance/exercise_picker_screen.dart';
import 'package:tennis_track/services/session_store.dart';
import 'package:tennis_track/utils/exercise_filters.dart';

void main() {
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

  TrainingSession session(
    BallColor color,
    TrainingCategory category,
    List<Exercise> exercises,
  ) =>
      TrainingSession(
        id: 0,
        date: DateTime(2026, 11, 2),
        durationMinutes: 60,
        intensity: 3,
        ballColor: color,
        categories: [category],
        exercises: exercises,
      );

  test('les catégories Attaque et Défense existent', () async {
    final names = (await repository.getCategories()).map((c) => c.nom);
    expect(names, containsAll(['Attaque', 'Défense']));
  });

  test('modifier un exercice met à jour toutes ses séances', () async {
    final categories = await repository.getCategories();
    final colors = await repository.getBallColors();
    final id = await repository.insertExercise(Exercise(
      id: 0,
      name: 'Service lifté',
      categories: [categories.first],
      ballColors: [colors.last],
    ));
    final exercise = (await repository.getExercises()).single;
    await repository
        .insertSession(session(colors.last, categories.first, [exercise]));
    await repository
        .insertSession(session(colors.last, categories.first, [exercise]));

    await repository.updateExercise(exercise.copyWith(
      name: 'Service lifté amélioré',
      ballColors: [colors[2], colors[3]],
    ));

    final sessions = await repository.getSessions();
    expect(sessions, hasLength(2));
    for (final item in sessions) {
      expect(item.exercises.single.id, id);
      expect(item.exercises.single.name, 'Service lifté amélioré');
      expect(item.exercises.single.ballColors, hasLength(2));
    }
    expect(await repository.getExercises(), hasLength(1));
  });

  test('supprimer une séance garde l’exercice, et inversement', () async {
    final categories = await repository.getCategories();
    final colors = await repository.getBallColors();
    final sessionId = await repository.insertSession(session(
      colors.first,
      categories.first,
      [const Exercise(id: 0, name: 'Volée')],
    ));
    final otherId = await repository.insertSession(session(
      colors.first,
      categories.first,
      await repository.getExercises(),
    ));

    await repository.deleteSession(sessionId);
    final exercises = await repository.getExercises();
    expect(exercises, hasLength(1));

    await repository.deleteExercise(exercises.single.id);
    final remaining = await repository.getSessions();
    expect(remaining.single.id, otherId);
    expect(remaining.single.exercises, isEmpty);
  });

  test('migration v4 -> v5 : fusionne et conserve les données', () async {
    final directory = await Directory.systemTemp.createTemp('tennistrack_v4');
    final path = p.join(directory.path, 'v4.db');

    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (database, version) async {
            for (final sql in const [
              'CREATE TABLE couleur_balle (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL UNIQUE)',
              'CREATE TABLE categorie (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL UNIQUE)',
              'CREATE TABLE seance (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, duree_minutes INTEGER NOT NULL, intensite INTEGER NOT NULL, couleur_balle_id INTEGER NOT NULL, heure_debut TEXT)',
              "CREATE TABLE exercice (id INTEGER PRIMARY KEY AUTOINCREMENT, seance_id INTEGER NOT NULL, nom TEXT NOT NULL, points_travailles TEXT NOT NULL DEFAULT '', deroulement TEXT NOT NULL DEFAULT '', image BLOB, FOREIGN KEY (seance_id) REFERENCES seance(id) ON DELETE CASCADE)",
              'CREATE INDEX idx_exercice_seance ON exercice(seance_id)',
              'CREATE TABLE seance_categorie (seance_id INTEGER NOT NULL, categorie_id INTEGER NOT NULL, PRIMARY KEY (seance_id, categorie_id))',
              "INSERT INTO couleur_balle (nom) VALUES ('Rouge'), ('Vert')",
              "INSERT INTO categorie (nom) VALUES ('Service'), ('Revers')",
              "INSERT INTO seance (date, duree_minutes, intensite, couleur_balle_id) VALUES ('2026-10-01', 60, 3, 1), ('2026-10-02', 60, 3, 2)",
              'INSERT INTO seance_categorie VALUES (1, 1), (2, 2)',
              "INSERT INTO exercice (seance_id, nom, points_travailles) VALUES (1, 'Panier', 'Lancer'), (2, 'Panier', 'Lancer'), (2, 'Volée', '')",
            ]) {
              await database.execute(sql);
            }
          },
        ));
    await old.close();

    final migrated = await openAppDatabase(path: path);
    final migratedRepository = TennisRepository(migrated);
    final exercises = await migratedRepository.getExercises();
    final sessions = await migratedRepository.getSessions();

    expect(await migrated.getVersion(), kDatabaseVersion);
    expect(exercises.map((e) => e.name), ['Panier', 'Volée']);
    expect(exercises.first.ballColors.map((c) => c.nom), ['Rouge', 'Vert']);
    expect(exercises.first.categories.map((c) => c.nom), ['Service', 'Revers']);
    expect(exercises.last.ballColors.map((c) => c.nom), ['Vert']);

    final bySession = {for (final item in sessions) item.id: item};
    expect(bySession[1]!.exercises.map((e) => e.name), ['Panier']);
    expect(bySession[2]!.exercises.map((e) => e.name), ['Panier', 'Volée']);
    expect(bySession[1]!.exercises.single.id, bySession[2]!.exercises.first.id);
    expect((await migratedRepository.getCategories()).map((c) => c.nom),
        containsAll(['Attaque', 'Défense']));

    await migrated.close();
    await directory.delete(recursive: true);
  });

  test('filtre par texte, catégorie et couleur de balle', () {
    const rouge = BallColor(id: 1, nom: 'Rouge');
    const vert = BallColor(id: 2, nom: 'Vert');
    const service = TrainingCategory(id: 1, nom: 'Service');
    const attaque = TrainingCategory(id: 2, nom: 'Attaque');
    const facile = Exercise(
        id: 1,
        name: 'Facile',
        categories: [service],
        ballColors: [rouge, vert]);
    const dur =
        Exercise(id: 2, name: 'Dur', categories: [attaque], ballColors: [vert]);

    expect(filterExercises([facile, dur], ballColorId: 1), [facile]);
    expect(filterExercises([facile, dur], categoryId: 2), [dur]);
    expect(filterExercises([facile, dur], query: 'dur'), [dur]);
    expect(filterExercises([facile, dur]), hasLength(2));
  });

  testWidgets('le choix démarre sur la couleur de balle de la séance',
      (tester) async {
    final store = SessionStore(repository: repository);
    late BallColor rouge;
    await tester.runAsync(() async {
      await store.load();
      rouge = store.ballColors.first;
      await store.saveExercise(Exercise(
        id: 0,
        name: 'Pour balle rouge',
        categories: [store.categories.first],
        ballColors: [rouge],
      ));
      await store.saveExercise(Exercise(
        id: 0,
        name: 'Trop dur',
        categories: [store.categories.first],
        ballColors: [store.ballColors.last],
      ));
    });

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ExercisePickerScreen(
        store: store,
        excludedIds: const {},
        ballColorId: rouge.id,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pour balle rouge'), findsOneWidget);
    expect(find.text('Trop dur'), findsNothing);

    await tester.tap(find.text('Toutes les balles'));
    await tester.pumpAndSettle();
    expect(find.text('Trop dur'), findsOneWidget);
  });
}

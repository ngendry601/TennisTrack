import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/models/models.dart';

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

  test('crée les catégories et les couleurs au premier lancement', () async {
    final categories = await repository.getCategories();
    final colors = await repository.getBallColors();

    expect(categories.map((category) => category.nom), kSeedCategories);
    expect(colors.map((color) => color.nom), kSeedBallColors);
  });

  test('enregistre, relit, modifie et supprime une séance', () async {
    final categories = await repository.getCategories();
    final colors = await repository.getBallColors();

    final id = await repository.insertSession(TrainingSession(
      id: 0,
      date: DateTime(2026, 10, 24),
      durationMinutes: 90,
      intensity: 4,
      ballColor: colors.first,
      categories: [categories[0], categories[3]],
      startTime: const TimeOfDay(hour: 18, minute: 15),
      exercises: [
        Exercise(
          id: 0,
          name: 'Service extérieur',
          pointsToWork: 'Lancer de balle et prise de raquette',
          execution: '3 séries de 10 services avec un panier de balles',
          image: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ],
    ));

    expect(id, greaterThan(0));

    var sessions = await repository.getSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.date, DateTime(2026, 10, 24));
    expect(sessions.single.durationMinutes, 90);
    expect(sessions.single.intensity, 4);
    expect(sessions.single.startTime, const TimeOfDay(hour: 18, minute: 15));
    expect(sessions.single.endTime, const TimeOfDay(hour: 19, minute: 45));
    expect(sessions.single.exercises, hasLength(1));
    expect(sessions.single.exercises.single.name, 'Service extérieur');
    expect(sessions.single.exercises.single.pointsToWork,
        'Lancer de balle et prise de raquette');
    expect(sessions.single.exercises.single.execution,
        '3 séries de 10 services avec un panier de balles');
    expect(sessions.single.exercises.single.image,
        Uint8List.fromList([1, 2, 3, 4]));
    expect(sessions.single.categories.map((category) => category.nom),
        ['Service', 'Volée / Filet']);

    await repository.updateSession(sessions.single.copyWith(
      date: DateTime(2026, 10, 25),
      durationMinutes: 60,
      categories: [categories[2]],
      exercises: [
        const Exercise(id: 0, name: 'Revers croisé'),
      ],
    ));

    sessions = await repository.getSessions();
    expect(sessions.single.date, DateTime(2026, 10, 25));
    expect(sessions.single.durationMinutes, 60);
    expect(sessions.single.startTime, const TimeOfDay(hour: 18, minute: 15));
    expect(sessions.single.categories.single.nom, 'Revers');
    expect(sessions.single.exercises.single.name, 'Revers croisé');

    await repository.deleteSession(id);
    expect(await repository.getSessions(), isEmpty);
  });

  test('supprimer une catégorie supprime ses séances (trigger)', () async {
    final categories = await repository.getCategories();
    final colors = await repository.getBallColors();

    await repository.insertSession(TrainingSession(
      id: 0,
      date: DateTime(2026, 10, 24),
      durationMinutes: 60,
      intensity: 2,
      ballColor: colors.first,
      categories: [categories.first],
    ));

    expect(await repository.getSessions(), hasLength(1));

    await db
        .delete('categorie', where: 'id = ?', whereArgs: [categories.first.id]);

    expect(await repository.getSessions(), isEmpty);
  });

  test('migre une base v1 vers v3 sans perdre les séances', () async {
    final directory = await Directory.systemTemp.createTemp('tennistrack_');
    final path = p.join(directory.path, 'v1.db');

    final oldDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE couleur_balle (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE categorie (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT NOT NULL UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE seance (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              duree_minutes INTEGER NOT NULL,
              intensite INTEGER NOT NULL,
              couleur_balle_id INTEGER NOT NULL,
              lieu TEXT NOT NULL DEFAULT '',
              notes TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute('''
            CREATE TABLE seance_categorie (
              seance_id INTEGER NOT NULL,
              categorie_id INTEGER NOT NULL,
              PRIMARY KEY (seance_id, categorie_id)
            )
          ''');
          await db.insert('couleur_balle', {'nom': 'Rouge'});
          await db.insert('categorie', {'nom': 'Service'});
          await db.insert('seance', {
            'date': '2026-10-24',
            'duree_minutes': 90,
            'intensite': 3,
            'couleur_balle_id': 1,
          });
          await db.insert('seance_categorie', {
            'seance_id': 1,
            'categorie_id': 1,
          });
        },
      ),
    );
    await oldDatabase.close();

    final migrated = await openAppDatabase(path: path);
    final migratedRepository = TennisRepository(migrated);
    final sessions = await migratedRepository.getSessions();

    expect(await migrated.getVersion(), 3);
    expect(sessions, hasLength(1));
    expect(sessions.single.date, DateTime(2026, 10, 24));
    expect(sessions.single.durationMinutes, 90);
    expect(sessions.single.startTime, isNull);
    expect(sessions.single.categories.single.nom, 'Service');
    expect(sessions.single.exercises, isEmpty);

    final columns = await migrated.rawQuery('PRAGMA table_info(seance)');
    final columnNames = columns.map((row) => row['name'] as String).toSet();
    expect(columnNames, contains('heure_debut'));
    expect(columnNames, isNot(contains('lieu')));
    expect(columnNames, isNot(contains('notes')));

    // Le trigger recréé après la migration fonctionne toujours.
    await migrated.delete('categorie', where: 'id = ?', whereArgs: [1]);
    expect(await migratedRepository.getSessions(), isEmpty);

    await migrated.close();
    await directory.delete(recursive: true);
  });
}

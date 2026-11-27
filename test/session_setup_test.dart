import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/screens/home_screen.dart';
import 'package:tennis_track/screens/session/session_detail_screen.dart';
import 'package:tennis_track/screens/session/session_form_screen.dart';
import 'package:tennis_track/services/session_store.dart';
import 'package:tennis_track/utils/home_stats.dart';
import 'package:tennis_track/utils/session_times.dart';

const _rouge = BallColor(id: 1, nom: 'Rouge');
const _service = TrainingCategory(id: 1, nom: 'Service');

TrainingSession _session({
  int id = 1,
  DateTime? date,
  int duration = 75,
  int setup = 0,
  int packUp = 0,
  TimeOfDay? start,
}) =>
    TrainingSession(
      id: id,
      date: date ?? DateTime(2026, 11, 20),
      durationMinutes: duration,
      intensity: 3,
      ballColor: _rouge,
      categories: const [_service],
      startTime: start,
      setupMinutes: setup,
      packUpMinutes: packUp,
    );

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: home),
    );

void main() {
  group('préparation et rangement', () {
    final cours = _session(
      setup: 15,
      packUp: 15,
      start: const TimeOfDay(hour: 9, minute: 15),
    );

    test('arrivée, départ et temps total sur place', () {
      expect(cours.totalMinutes, 105);
      expect(cours.arrivalTime, const TimeOfDay(hour: 9, minute: 0));
      expect(cours.departureTime, const TimeOfDay(hour: 10, minute: 45));
    });

    test('textes affichés', () {
      expect(formatSetupPackUp(cours), 'Prépa 15min · rangement 15min');
      expect(formatSetupPackUp(_session(packUp: 10)), 'Rangement 10min');
      expect(formatSetupPackUp(_session()), isNull);

      expect(formatOnSite(cours), 'Sur place 9h00 – 10h45 · 1h45min');
      expect(formatOnSite(_session(setup: 15)), 'Sur place 1h30min');
      expect(formatOnSite(_session()), isNull);
    });

    test('les statistiques comptent préparation et rangement', () {
      final shares = categoryShares([cours]);
      expect(shares.single.minutes, 105);
    });

    test('la dernière séance enregistrée sert de modèle', () {
      expect(
        lastEnteredSession([
          _session(id: 2, date: DateTime(2026, 12, 1)),
          _session(id: 5, date: DateTime(2026, 11, 1), setup: 20),
        ])?.setupMinutes,
        20,
      );
      expect(lastEnteredSession([]), isNull);
    });
  });

  group('avec la base', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Database db;
    late SessionStore store;

    setUp(() async {
      db = await openAppDatabase(path: inMemoryDatabasePath);
      store = SessionStore(repository: TennisRepository(db));
      await store.load();
    });

    tearDown(() async {
      await db.close();
    });

    TrainingSession stored({
      required DateTime date,
      TimeOfDay? start,
      int setup = 0,
      int packUp = 0,
      int categoryIndex = 0,
    }) =>
        TrainingSession(
          id: 0,
          date: date,
          durationMinutes: 60,
          intensity: 3,
          ballColor: store.ballColors.first,
          categories: [store.categories[categoryIndex]],
          startTime: start,
          setupMinutes: setup,
          packUpMinutes: packUp,
        );

    test('enregistre et relit la préparation et le rangement', () async {
      await store.upsert(stored(date: DateTime(2026, 11, 20), setup: 15));
      expect(store.sessions.single.setupMinutes, 15);
      expect(store.sessions.single.packUpMinutes, 0);
      expect(store.totalMinutes, 75);

      await store.upsert(store.sessions.single.copyWith(packUpMinutes: 10));
      expect(store.sessions.single.packUpMinutes, 10);
      expect(store.totalMinutes, 85);
    });

    test('refuse un temps négatif', () async {
      await store.upsert(stored(date: DateTime(2026, 11, 20)));
      expect(
        () => db.update('seance', {'preparation_minutes': -5}),
        throwsA(isA<DatabaseException>()),
      );
    });

    testWidgets('une nouvelle séance reprend la prépa de la dernière',
        (tester) async {
      await tester.runAsync(() => store.upsert(stored(
            date: DateTime(2026, 11, 20),
            setup: 15,
            packUp: 10,
          )));

      await tester.pumpWidget(_app(SessionFormScreen(store: store)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Rangement après le cours : 10min'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Préparation avant le cours : 15min'), findsOneWidget);
      expect(find.text('Rangement après le cours : 10min'), findsOneWidget);
    });

    testWidgets('les détails affichent le temps sur place', (tester) async {
      await tester.runAsync(() => store.upsert(stored(
            date: DateTime(2026, 11, 20),
            start: const TimeOfDay(hour: 9, minute: 15),
            setup: 15,
            packUp: 15,
          )));

      await tester.pumpWidget(_app(SessionDetailScreen(
        store: store,
        session: store.sessions.single,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Prépa 15min · rangement 15min'), findsOneWidget);
      expect(find.text('Sur place 9h00 – 10h30 · 1h30min'), findsOneWidget);
    });

    testWidgets('l’accueil montre toutes les séances du dernier jour',
        (tester) async {
      await tester.runAsync(() async {
        await store.upsert(stored(
          date: DateTime(2026, 11, 18),
          start: const TimeOfDay(hour: 8, minute: 0),
        ));
        await store.upsert(stored(
          date: DateTime(2026, 11, 21),
          start: const TimeOfDay(hour: 17, minute: 0),
          categoryIndex: 1,
        ));
        await store.upsert(stored(
          date: DateTime(2026, 11, 21),
          start: const TimeOfDay(hour: 9, minute: 15),
          setup: 15,
        ));
      });

      await tester.pumpWidget(_app(HomeScreen(
        store: store,
        today: DateTime(2026, 11, 27),
      )));
      await tester.pumpAndSettle();

      final title = find.text('Dernier jour');
      await tester.scrollUntilVisible(title, 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('2 séances · 2h15min'), findsOneWidget);
      expect(find.text('Samedi 21 novembre 2026'), findsOneWidget);
      expect(find.text('9h15 – 10h15 · 1h'), findsOneWidget);
      expect(find.text('17h00 – 18h00 · 1h'), findsOneWidget);
      // La séance du 18 novembre n'est pas du dernier jour.
      expect(find.text('8h00 – 9h00 · 1h'), findsNothing);
    });
  });

  test('migration v6 -> v7 : les séances existantes gardent 0 minute',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('tennistrack_v6');
    final path = p.join(directory.path, 'v6.db');

    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (database, version) async {
            for (final sql in const [
              'CREATE TABLE couleur_balle (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL UNIQUE)',
              'CREATE TABLE categorie (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL UNIQUE)',
              'CREATE TABLE seance (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, duree_minutes INTEGER NOT NULL, intensite INTEGER NOT NULL, couleur_balle_id INTEGER NOT NULL, heure_debut TEXT)',
              'CREATE TABLE seance_categorie (seance_id INTEGER NOT NULL, categorie_id INTEGER NOT NULL, PRIMARY KEY (seance_id, categorie_id))',
              "CREATE TABLE exercice (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT NOT NULL, points_travailles TEXT NOT NULL DEFAULT '', deroulement TEXT NOT NULL DEFAULT '', image BLOB, duree_minutes INTEGER)",
              'CREATE TABLE seance_exercice (seance_id INTEGER NOT NULL, exercice_id INTEGER NOT NULL, ordre INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (seance_id, exercice_id))',
              'CREATE TABLE exercice_categorie (exercice_id INTEGER NOT NULL, categorie_id INTEGER NOT NULL, PRIMARY KEY (exercice_id, categorie_id))',
              'CREATE TABLE exercice_couleur_balle (exercice_id INTEGER NOT NULL, couleur_balle_id INTEGER NOT NULL, PRIMARY KEY (exercice_id, couleur_balle_id))',
              "INSERT INTO couleur_balle (nom) VALUES ('Rouge')",
              "INSERT INTO seance (date, duree_minutes, intensite, couleur_balle_id, heure_debut) VALUES ('2026-11-20', 75, 3, 1, '09:15')",
            ]) {
              await database.execute(sql);
            }
          },
        ));
    await old.close();

    final migrated = await openAppDatabase(path: path);
    final session = (await TennisRepository(migrated).getSessions()).single;

    expect(await migrated.getVersion(), kDatabaseVersion);
    expect(session.durationMinutes, 75);
    expect(session.startTime, const TimeOfDay(hour: 9, minute: 15));
    expect(session.setupMinutes, 0);
    expect(session.packUpMinutes, 0);

    await migrated.close();
    await directory.delete(recursive: true);
  });
}

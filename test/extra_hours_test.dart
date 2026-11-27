import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/main.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/screens/calendar_screen.dart';
import 'package:tennis_track/screens/monthly_stats_screen.dart';
import 'package:tennis_track/services/session_store.dart';
import 'package:tennis_track/utils/extra_hours.dart';
import 'package:tennis_track/utils/home_stats.dart';

ExtraHours _hours(int id, DateTime date, int minutes, [String comment = '']) =>
    ExtraHours(id: id, date: date, durationMinutes: minutes, comment: comment);

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: home),
    );

void main() {
  group('calculs', () {
    test('libellé par défaut quand le commentaire est vide', () {
      expect(_hours(1, DateTime(2026, 11, 1), 60).label, 'Autres heures');
      expect(_hours(1, DateTime(2026, 11, 1), 60, 'Championnat').label,
          'Championnat');
    });

    test('suggestions : derniers commentaires puis valeurs par défaut', () {
      final suggestions = extraHoursCommentSuggestions([
        _hours(1, DateTime(2026, 11, 1), 60, 'Plateau U10'),
        _hours(2, DateTime(2026, 11, 8), 60, 'championnat'),
      ], max: 4);
      // Le plus récent d'abord ; « Championnat » n'est pas proposé deux fois.
      expect(
          suggestions, ['championnat', 'Plateau U10', 'Tournoi', 'Aide coach']);
    });

    test('la répartition du mois montre les heures hors séances', () {
      final shares = categoryShares(const [], extraMinutes: 240);
      expect(shares.single.name, kExtraHoursShareName);
      expect(shares.single.percent, 100);
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

    test('ajoute, modifie et supprime des heures', () async {
      await store.saveExtraHours(
          _hours(0, DateTime(2026, 11, 14), 240, ' Championnat '));
      final saved = store.extraHours.single;
      expect(saved.comment, 'Championnat');
      expect(store.totalMinutes, 240);
      // Pas une séance : le nombre de séances ne bouge pas.
      expect(store.sessions, isEmpty);

      await store
          .saveExtraHours(_hours(saved.id, saved.date, 150, 'Aide coach'));
      expect(store.extraHours.single.durationMinutes, 150);
      expect(store.extraHours.single.comment, 'Aide coach');

      await store.removeExtraHours(saved.id);
      expect(store.extraHours, isEmpty);
      expect(store.totalMinutes, 0);
    });

    test('refuse une durée nulle', () async {
      expect(
        () => db.insert('activite', {'date': '2026-11-14', 'duree_minutes': 0}),
        throwsA(isA<DatabaseException>()),
      );
    });

    testWidgets('le lien de l’accueil enregistre des heures', (tester) async {
      await tester.pumpWidget(TennisTrackApp(store: store));
      await tester.pumpAndSettle();

      // Pas de bouton flottant « Heures » : seulement un lien discret.
      expect(find.text('Heures'), findsNothing);
      await tester.tap(find.text('Ajouter des heures hors séance'));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter des heures'), findsOneWidget);

      await tester.tap(find.text('Championnat'));
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      for (var i = 0; i < 200 && store.extraHours.isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }

      expect(store.extraHours.single.comment, 'Championnat');
      expect(store.extraHours.single.durationMinutes, 120);
    });

    testWidgets('le calendrier affiche les heures du jour', (tester) async {
      await tester.runAsync(() => store.saveExtraHours(
          _hours(0, DateTime(2026, 11, 14), 150, 'Aide coach')));

      await tester.pumpWidget(_app(CalendarScreen(
        store: store,
        initialDate: DateTime(2026, 11, 14),
      )));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Aide coach'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 hors séance · 2h30min au total'), findsOneWidget);
      expect(find.text('Aide coach'), findsOneWidget);
    });

    testWidgets('les stats comptent les heures hors séances', (tester) async {
      await tester.runAsync(() => store.saveExtraHours(
          _hours(0, DateTime(2026, 11, 14), 240, 'Championnat')));

      await tester.pumpWidget(_app(MonthlyStatsScreen(store: store)));
      await tester.pumpAndSettle();

      expect(find.text('0 séance · 1 hors séance · 4h'), findsOneWidget);
      await tester.tap(find.text('0 séance · 1 hors séance · 4h'));
      await tester.pumpAndSettle();
      expect(find.text(kExtraHoursShareName), findsOneWidget);
      expect(find.text('Championnat'), findsOneWidget);
    });
  });

  test('migration v7 -> v8 : crée la table des heures hors séances', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('tennistrack_v7');
    final path = p.join(directory.path, 'v7.db');

    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (database, version) => database.execute(
              'CREATE TABLE seance (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              "date TEXT NOT NULL, duree_minutes INTEGER NOT NULL)"),
        ));
    await old.execute(
        "INSERT INTO seance (date, duree_minutes) VALUES ('2026-11-20', 60)");
    await old.close();

    final migrated = await openAppDatabase(path: path);
    final repository = TennisRepository(migrated);

    expect(await migrated.getVersion(), kDatabaseVersion);
    expect(await repository.getExtraHours(), isEmpty);
    await repository
        .insertExtraHours(_hours(0, DateTime(2026, 11, 21), 90, 'Tournoi'));
    expect((await repository.getExtraHours()).single.label, 'Tournoi');
    // La séance existante est toujours là.
    expect(await migrated.query('seance'), hasLength(1));

    await migrated.close();
    await directory.delete(recursive: true);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tennis_track/data/database.dart';
import 'package:tennis_track/data/tennis_repository.dart';
import 'package:tennis_track/models/models.dart';
import 'package:tennis_track/screens/calendar_screen.dart';
import 'package:tennis_track/screens/home_screen.dart';
import 'package:tennis_track/screens/monthly_stats_screen.dart';
import 'package:tennis_track/screens/sessions_screen.dart';
import 'package:tennis_track/services/session_store.dart';

void main() {
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

    final categories = store.categories;
    final colors = store.ballColors;

    await store.upsert(TrainingSession(
      id: 0,
      date: DateTime(2026, 9, 12),
      durationMinutes: 60,
      intensity: 3,
      ballColor: colors.first,
      categories: [categories[0]],
    ));
    await store.upsert(TrainingSession(
      id: 0,
      date: DateTime(2026, 10, 24),
      durationMinutes: 90,
      intensity: 4,
      ballColor: colors[1],
      categories: [categories[0], categories[1]],
      startTime: const TimeOfDay(hour: 18, minute: 0),
      exercises: const [
        Exercise(
          id: 0,
          name: 'Service lifté',
          pointsToWork: 'Lancer de balle',
          execution: 'Panier de balles, 3 séries de 10',
        ),
      ],
    ));
  });

  tearDown(() async {
    await db.close();
  });

  Widget app(Widget home) => MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: home),
      );

  testWidgets('accueil : stats du mois en cours et liste de la semaine',
      (tester) async {
    await tester.pumpWidget(app(HomeScreen(
      store: store,
      today: DateTime(2026, 10, 24),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Séances ce mois'), findsOneWidget);
    expect(find.text('Heures ce mois'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('1h30min'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.textContaining('24 oct.'), findsOneWidget);
    // La séance de septembre reste dans l'onglet Séances, pas sur l'accueil.
    expect(find.textContaining('12 sept.'), findsNothing);

    // Une semaine plus tard : la séance du 24 octobre est toujours dans les
    // stats du mois, mais plus dans la liste de la semaine.
    await tester.pumpWidget(app(HomeScreen(
      store: store,
      today: DateTime(2026, 10, 31),
    )));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('1h30min'), findsOneWidget);
    expect(find.text('Aucune séance cette semaine 🎾'), findsOneWidget);
    expect(find.textContaining('24 oct.'), findsNothing);
  });

  testWidgets('affiche les heures par mois avec le bon format', (tester) async {
    await tester.pumpWidget(app(MonthlyStatsScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.text('Octobre 2026'), findsOneWidget);
    expect(find.textContaining('1h'), findsWidgets);
    expect(find.textContaining('1h30min'), findsOneWidget);
  });

  testWidgets('le calendrier affiche les horaires et les thèmes du jour',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(CalendarScreen(
      store: store,
      initialDate: DateTime(2026, 10, 1),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Octobre 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-day-2026-10-24')));
    await tester.pumpAndSettle();

    expect(find.text('18h00 – 19h30 · 1h30min'), findsOneWidget);
    expect(find.text('Service'), findsWidgets);
    expect(find.text('Coup droit'), findsWidgets);
    expect(find.text('Service lifté'), findsOneWidget);
    expect(find.textContaining('1h30min au total'), findsOneWidget);
  });

  testWidgets(
      'ouvre les détails d’une séance puis le formulaire de modification',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(SessionsScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Service · Coup droit'));
    await tester.pumpAndSettle();

    expect(find.text('Détails de la séance'), findsOneWidget);
    expect(find.text('Service lifté'), findsOneWidget);
    expect(find.text('Lancer de balle'), findsOneWidget);
    expect(find.text('Panier de balles, 3 séries de 10'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la séance'), findsOneWidget);
  });

  testWidgets('supprime une séance depuis l’onglet Séances', (tester) async {
    await tester.pumpWidget(app(SessionsScreen(store: store)));
    await tester.pumpAndSettle();

    expect(store.sessions, hasLength(2));
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Supprimer la séance ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(store.sessions, hasLength(1));
  });
}

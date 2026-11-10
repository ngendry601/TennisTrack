import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tennis_track/widgets/bar/bottom_navbar.dart';

import 'data/database_factory_init.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  final store = SessionStore();
  await store.load();
  runApp(TennisTrackApp(store: store));
}

class TennisTrackApp extends StatelessWidget {
  const TennisTrackApp({super.key, required this.store});
  final SessionStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TennisTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7CB518), // vert balle de tennis
        useMaterial3: true,
      ),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: MainShell(store: store),
    );
  }
}

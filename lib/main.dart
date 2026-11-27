import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tennis_track/widgets/bar/bottom_navbar.dart';

import 'data/database_factory_init.dart';
import 'services/session_store.dart';
import 'theme/app_theme.dart';

// POINT D'ENTRÉE de l'application : c'est la première fonction exécutée.
// `async` permet d'attendre (`await`) le chargement de la base avant
// d'afficher le premier écran.
Future<void> main() async {
  // Obligatoire avant d'utiliser des plugins (ici SQLite) avant `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  // Choisit la bonne version de SQLite selon la plateforme (téléphone ou PC).
  initDatabaseFactory();
  // Le « store » garde toutes les données en mémoire et parle à la base.
  // Il est créé une seule fois ici, puis transmis à tous les écrans.
  final store = SessionStore();
  // Ouvre (ou crée) la base SQLite et charge séances, exercices, catégories…
  await store.load();
  // Lance l'interface : Flutter affiche le widget TennisTrackApp.
  runApp(TennisTrackApp(store: store));
}

// Widget racine. « Stateless » : il n'a pas d'état qui change, il se contente
// de configurer l'application (thème, langue, premier écran).
class TennisTrackApp extends StatelessWidget {
  const TennisTrackApp({super.key, required this.store});
  final SessionStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TennisTrack',
      debugShowCheckedModeBanner: false,
      // Couleurs et styles de toute l'appli : voir lib/theme/app_theme.dart.
      theme: buildAppTheme(),
      // Application uniquement en français (dates, boutons système…).
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Premier écran affiché : la structure avec les 5 onglets du bas.
      home: MainShell(store: store),
    );
  }
}

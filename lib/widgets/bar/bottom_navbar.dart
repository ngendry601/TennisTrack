import 'package:flutter/material.dart';

import '../../services/session_store.dart';
import '../../screens/calendar_screen.dart';
import '../../screens/extra_hours_form_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/monthly_stats_screen.dart';
import '../../screens/seance/exercise_form_screen.dart';
import '../../screens/seance/exercise_library_screen.dart';
import '../../screens/session/session_form_screen.dart';
import '../../screens/session/sessions_screen.dart';
import 'appbar.dart';

// STRUCTURE PRINCIPALE de l'appli : barre du haut, onglets du bas et bouton
// flottant. « Stateful » car elle retient quel onglet est sélectionné.
// Un StatefulWidget est toujours en deux parties : le widget (paramètres
// fixes, ici le store) et son State (données qui changent, ici l'onglet).
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final SessionStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Onglet affiché : 0 = Accueil, 1 = Séances, 2 = Exercices, 3 = Calendrier,
  // 4 = Stats. Le « _ » devant un nom veut dire « privé à ce fichier ».
  int _selectedIndex = 0;

  static const _titles = [
    'TennisTrack',
    'Séances',
    'Exercices',
    'Calendrier',
    'Statistiques',
  ];

  // Sur l'onglet Exercices, le bouton flottant crée un exercice au lieu
  // d'une séance.
  static const _exercisesIndex = 2;

  // IndexedStack conserve l'état des onglets (recherche, filtres)
  // quand on passe de l'un à l'autre.
  late final List<Widget> _pages;

  @override
  // initState est appelé une seule fois, à la création de l'écran.
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(store: widget.store),
      SessionsScreen(store: widget.store),
      ExerciseLibraryScreen(store: widget.store),
      CalendarScreen(store: widget.store),
      MonthlyStatsScreen(store: widget.store),
    ];
  }

  // Navigator.push ouvre un nouvel écran par-dessus l'actuel ; le bouton
  // retour le referme et revient ici.
  void _openNewSession() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionFormScreen(store: widget.store),
    ));
  }

  void _openExtraHours() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExtraHoursFormScreen(store: widget.store),
    ));
  }

  void _openNewExercise() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseFormScreen(store: widget.store),
    ));
  }

  @override
  // build décrit ce qu'il faut afficher. Flutter le rappelle à chaque
  // setState(), et redessine seulement ce qui a changé.
  Widget build(BuildContext context) {
    final onExercises = _selectedIndex == _exercisesIndex;

    return Scaffold(
      appBar: AppBar_Perso(
        title: _titles[_selectedIndex],
        onProfilePressed: () {
          // Handle profile press
        },
      ),
      // IndexedStack garde les 5 écrans en mémoire et n'en montre qu'un :
      // la recherche ou les filtres d'un onglet sont conservés quand on revient.
      body: IndexedStack(index: _selectedIndex, children: _pages),
      // Bouton flottant global, visible sur tous les onglets.
      // Deux boutons empilés : « Heures » (heures hors séances, sauf sur
      // l'onglet Exercices) au-dessus du bouton principal.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!onExercises) ...[
            FloatingActionButton.extended(
              // Deux boutons flottants sur un même écran doivent avoir des
              // heroTag différents, sinon Flutter signale une erreur.
              heroTag: 'heures',
              onPressed: _openExtraHours,
              icon: const Icon(Icons.more_time),
              label: const Text('Heures'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'principal',
            onPressed: onExercises ? _openNewExercise : _openNewSession,
            icon: const Icon(Icons.add),
            label: Text(onExercises ? 'Exercice' : 'Séance'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        // setState() enregistre le nouvel onglet ET demande de redessiner l'écran.
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.sports_tennis_outlined),
              selectedIcon: Icon(Icons.sports_tennis),
              label: 'Séances'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Exercices'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendrier'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Stats'),
        ],
      ),
    );
  }
}

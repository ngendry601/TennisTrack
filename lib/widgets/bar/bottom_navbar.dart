import 'package:flutter/material.dart';

import '../../services/session_store.dart';
import '../../screens/calendar_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/monthly_stats_screen.dart';
import '../../screens/session/session_form_screen.dart';
import '../../screens/session/sessions_screen.dart';
import 'appbar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final SessionStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _titles = [
    'TennisTrack',
    'Séances',
    'Calendrier',
    'Statistiques',
  ];

  // IndexedStack conserve l'état des onglets (recherche, filtres)
  // quand on passe de l'un à l'autre.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(store: widget.store),
      SessionsScreen(store: widget.store),
      CalendarScreen(store: widget.store),
      MonthlyStatsScreen(store: widget.store),
    ];
  }

  void _openNewSession() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionFormScreen(store: widget.store),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar_Perso(
        title: _titles[_selectedIndex],
        onProfilePressed: () {
          // Handle profile press
        },
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSession,
        icon: const Icon(Icons.add),
        label: const Text('Séance'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
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

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/session_store.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete_session.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.store});

  final SessionStore store;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _searchController = TextEditingController();
  int? _categoryId;
  int? _intensity;
  int? _duration;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<TrainingSession> _filteredSessions() {
    final query = _searchController.text.trim().toLowerCase();
    return widget.store.sessions.where((session) {
      final searchable = [
        ...session.categories.map((category) => category.nom),
        ...session.exercises.map((exercise) => exercise.name),
        ...session.exercises.map((exercise) => exercise.pointsToWork),
        ...session.exercises.map((exercise) => exercise.execution),
        session.ballColor.nom,
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || searchable.contains(query);
      final matchesCategory = _categoryId == null ||
          session.categories.any((category) => category.id == _categoryId);
      final matchesIntensity =
          _intensity == null || session.intensity == _intensity;
      final matchesDuration = _duration == null ||
          (_duration == 60 && session.durationMinutes < 60) ||
          (_duration == 90 &&
              session.durationMinutes >= 60 &&
              session.durationMinutes <= 90) ||
          (_duration == 120 && session.durationMinutes > 90);
      return matchesSearch &&
          matchesCategory &&
          matchesIntensity &&
          matchesDuration;
    }).toList();
  }

  bool get _hasFilters =>
      _categoryId != null || _intensity != null || _duration != null;

  void _openDetails(TrainingSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SessionDetailScreen(store: widget.store, session: session),
    ));
  }

  Future<void> _deleteSession(TrainingSession session) async {
    final confirmed = await confirmDeleteSession(context, session);
    if (!confirmed || !mounted) return;
    await widget.store.remove(session.id);
  }

  void _clearFilters() {
    setState(() {
      _categoryId = null;
      _intensity = null;
      _duration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final sessions = _filteredSessions();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher une séance, un exercice...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchController.clear),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            _FiltersBar(
              categories: widget.store.categories,
              categoryId: _categoryId,
              intensity: _intensity,
              duration: _duration,
              hasFilters: _hasFilters,
              onCategoryChanged: (value) => setState(() => _categoryId = value),
              onIntensityChanged: (value) => setState(() => _intensity = value),
              onDurationChanged: (value) => setState(() => _duration = value),
              onClear: _clearFilters,
            ),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text(widget.store.sessions.isEmpty
                          ? 'Aucune séance enregistrée'
                          : 'Aucune séance ne correspond aux filtres'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _SessionTile(
                          session: session,
                          onTap: () => _openDetails(session),
                          onDelete: () => _deleteSession(session),
                          confirmDismiss: () =>
                              confirmDeleteSession(context, session),
                          onDismissed: () => widget.store.remove(session.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.categories,
    required this.categoryId,
    required this.intensity,
    required this.duration,
    required this.hasFilters,
    required this.onCategoryChanged,
    required this.onIntensityChanged,
    required this.onDurationChanged,
    required this.onClear,
  });

  final List<TrainingCategory> categories;
  final int? categoryId;
  final int? intensity;
  final int? duration;
  final bool hasFilters;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onIntensityChanged;
  final ValueChanged<int?> onDurationChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    TrainingCategory? category;
    for (final item in categories) {
      if (item.id == categoryId) {
        category = item;
        break;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(category?.nom ?? 'Catégorie'),
            avatar: const Icon(Icons.category_outlined, size: 18),
            selected: categoryId != null,
            onSelected: (_) => _showCategoryMenu(context),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(intensity == null ? 'Intensité' : '$intensity / 5'),
            avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
            selected: intensity != null,
            onSelected: (_) => _showOptions(
                context,
                'Intensité',
                [null, 1, 2, 3, 4, 5],
                (value) => value == null ? 'Toutes' : '$value / 5',
                onIntensityChanged),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(duration == null ? 'Durée' : _durationLabel),
            avatar: const Icon(Icons.schedule, size: 18),
            selected: duration != null,
            onSelected: (_) => _showOptions(context, 'Durée',
                [null, 60, 90, 120], _durationName, onDurationChanged),
          ),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear),
                label: const Text('Réinitialiser')),
          ],
        ],
      ),
    );
  }

  String get _durationLabel => _durationName(duration);

  String _durationName(int? value) => switch (value) {
        null => 'Toutes',
        60 => '< 1 h',
        90 => '1 h à 1 h 30',
        _ => '> 1 h 30',
      };

  void _showCategoryMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
                title: const Text('Toutes les catégories'),
                onTap: () {
                  onCategoryChanged(null);
                  Navigator.pop(context);
                }),
            for (final category in categories)
              ListTile(
                  leading: Icon(category.icon),
                  title: Text(category.nom),
                  onTap: () {
                    onCategoryChanged(category.id);
                    Navigator.pop(context);
                  }),
          ],
        ),
      ),
    );
  }

  void _showOptions<T>(BuildContext context, String title, List<T?> options,
      String Function(T?) label, ValueChanged<T?> onChanged) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Text(title, style: Theme.of(context).textTheme.titleLarge)),
            for (final option in options)
              ListTile(
                  title: Text(label(option)),
                  onTap: () {
                    onChanged(option);
                    Navigator.pop(context);
                  }),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  final TrainingSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<bool> Function() confirmDismiss;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final date =
        MaterialLocalizations.of(context).formatMediumDate(session.date);

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete, color: Colors.white)),
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          child: Icon(session.categories.isEmpty
              ? Icons.sports_tennis
              : session.categories.first.icon),
        ),
        title: Text(
          session.categories.isEmpty
              ? 'Sans catégorie'
              : session.categories.map((category) => category.nom).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$date · ${formatTimeRange(session.startTime, session.durationMinutes)}'
              '${session.exercises.isEmpty ? '' : ' · ${session.exercises.length} exo${session.exercises.length > 1 ? 's' : ''}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: session.ballColor.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  session.ballColor.nom,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                ...List.generate(
                    5,
                    (index) => Icon(
                        index < session.intensity
                            ? Icons.local_fire_department
                            : Icons.local_fire_department_outlined,
                        size: 14,
                        color: Colors.orange)),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

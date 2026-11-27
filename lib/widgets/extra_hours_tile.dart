import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/extra_hours_form_screen.dart';
import '../services/session_store.dart';
import '../utils/formatters.dart';
import 'session_card_frame.dart';

/// Carte d'une entrée « Autres heures » (championnat, aide coach…), utilisée
/// sur l'accueil, dans le calendrier et dans les stats. Un appui ouvre le
/// formulaire pour la modifier ou la supprimer.
class ExtraHoursTile extends StatelessWidget {
  const ExtraHoursTile({
    super.key,
    required this.store,
    required this.hours,
    this.showDate = true,
  });

  final SessionStore store;
  final ExtraHours hours;

  /// Afficher la date (inutile dans le calendrier, où le jour est connu).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context).formatMediumDate(hours.date);
    final duration = formatDuration(hours.durationMinutes);

    return SessionCardFrame(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.more_time)),
        title: Text(hours.label),
        subtitle: Text(showDate
            ? '$date · $duration · hors séance'
            : '$duration · hors séance'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ExtraHoursFormScreen(store: store, hours: hours),
        )),
      ),
    );
  }
}

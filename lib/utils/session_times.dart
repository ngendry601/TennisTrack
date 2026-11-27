import 'package:flutter/material.dart';

import '../models/models.dart';
import 'formatters.dart';

/// Préparation et rangement maximum proposés dans le formulaire.
const int kMaxSetupPackUpMinutes = 60;

/// « Prépa 15min · rangement 10min », ou `null` s'il n'y a ni l'un ni
/// l'autre.
String? formatSetupPackUp(TrainingSession session) {
  final parts = [
    if (session.setupMinutes > 0)
      'Prépa ${formatDuration(session.setupMinutes)}',
    if (session.packUpMinutes > 0)
      'rangement ${formatDuration(session.packUpMinutes)}',
  ];
  if (parts.isEmpty) return null;
  final text = parts.join(' · ');
  return text[0].toUpperCase() + text.substring(1);
}

/// Temps sur place (préparation + cours + rangement) :
/// « Sur place 9h00 – 10h45 · 1h45min », ou « Sur place 1h45min » sans
/// heure de début. `null` s'il n'y a ni préparation ni rangement : le temps
/// sur place est alors celui du cours.
String? formatOnSite(TrainingSession session) => formatOnSiteFor(
      startTime: session.startTime,
      setupMinutes: session.setupMinutes,
      durationMinutes: session.durationMinutes,
      packUpMinutes: session.packUpMinutes,
    );

/// Même chose que [formatOnSite], à partir des valeurs d'un formulaire.
String? formatOnSiteFor({
  required TimeOfDay? startTime,
  required int setupMinutes,
  required int durationMinutes,
  required int packUpMinutes,
}) {
  if (setupMinutes == 0 && packUpMinutes == 0) return null;

  final total = formatDuration(setupMinutes + durationMinutes + packUpMinutes);
  if (startTime == null) return 'Sur place $total';

  final start = startTime.hour * 60 + startTime.minute;
  final arrival = _clock(start - setupMinutes);
  final departure = _clock(start + durationMinutes + packUpMinutes);
  return 'Sur place ${formatTime(arrival)} – ${formatTime(departure)} · $total';
}

TimeOfDay _clock(int minutes) {
  final wrapped = minutes % (24 * 60);
  return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
}

/// Séance enregistrée en dernier (plus grand id), pour reprendre sa
/// préparation et son rangement dans une nouvelle séance.
TrainingSession? lastEnteredSession(List<TrainingSession> sessions) {
  TrainingSession? last;
  for (final session in sessions) {
    if (last == null || session.id > last.id) last = session;
  }
  return last;
}

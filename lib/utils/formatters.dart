import 'package:flutter/material.dart';

/// Formate une durée en minutes au format « 1h15min ».
///
/// Exemples :
/// - 45  -> 45min
/// - 60  -> 1h
/// - 75  -> 1h15min
/// - 125 -> 2h05min
String formatDuration(int totalMinutes) {
  if (totalMinutes <= 0) return '0min';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) return '${minutes}min';
  if (minutes == 0) return '${hours}h';
  return '${hours}h${minutes.toString().padLeft(2, '0')}min';
}

/// Formate une heure au format français « 18h05 ».
String formatTime(TimeOfDay time) =>
    '${time.hour}h${time.minute.toString().padLeft(2, '0')}';

/// Formate une plage horaire, par exemple « 18h00 – 19h15 · 1h15min ».
///
/// Si l'heure de début n'est pas connue (anciennes séances), seule la
/// durée est affichée.
String formatTimeRange(TimeOfDay? start, int durationMinutes) {
  if (start == null) return formatDuration(durationMinutes);

  final total = start.hour * 60 + start.minute + durationMinutes;
  final end = TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  return '${formatTime(start)} – ${formatTime(end)} · '
      '${formatDuration(durationMinutes)}';
}

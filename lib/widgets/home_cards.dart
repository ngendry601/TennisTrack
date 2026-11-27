import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/session_times.dart';
import '../utils/home_stats.dart';

/// Ligne L M M J V S D : jours joués en jaune sur indigo, aujourd'hui repéré
/// par un point.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekdays,
    required this.playedWeekdays,
    required this.todayWeekday,
  });

  final List<CalendarWeekday> weekdays;

  /// Jours joués, au format `DateTime.weekday`.
  final Set<int> playedWeekdays;
  final int todayWeekday;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
        child: Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: _WeekDay(
                  key: Key('home-week-day-${weekday.id}'),
                  weekday: weekday,
                  played: playedWeekdays.contains(weekday.id),
                  isToday: weekday.id == todayWeekday,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    super.key,
    required this.weekday,
    required this.played,
    required this.isToday,
  });

  final CalendarWeekday weekday;
  final bool played;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final status = [
      played ? 'séance jouée' : 'pas de séance',
      if (isToday) "aujourd'hui",
    ].join(', ');

    return Semantics(
      label: '${weekday.nom}, $status',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: played ? AppColors.indigo : AppColors.lavender,
              shape: BoxShape.circle,
            ),
            child: Text(
              weekday.abreviation.substring(0, 1),
              style: TextStyle(
                color: played ? AppColors.neon : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isToday ? AppColors.indigo : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Anneau de la catégorie principale, top 3 et comparaison au mois dernier.
class MonthBreakdownCard extends StatelessWidget {
  const MonthBreakdownCard({
    super.key,
    required this.shares,
    required this.deltaMinutes,
    required this.comparison,
  });

  final List<CategoryShare> shares;
  final int deltaMinutes;

  /// Texte de comparaison, ou `null` s'il n'y a rien à comparer.
  final String? comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = comparison;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shares.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucune séance ce mois-ci',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Row(
                children: [
                  _CategoryRing(share: shares.first),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Les plus travaillées',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final share in shares.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    share.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${share.percent} %',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.indigo,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            if (text != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      deltaMinutes > 0
                          ? Icons.trending_up
                          : deltaMinutes < 0
                              ? Icons.trending_down
                              : Icons.trending_flat,
                      color: AppColors.indigo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRing extends StatelessWidget {
  const _CategoryRing({required this.share});

  final CategoryShare share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.square(
      dimension: 132,
      child: CustomPaint(
        painter: _RingPainter(share.percent.clamp(0, 100) / 100),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${share.percent} %',
                style:
                    theme.textTheme.titleLarge?.copyWith(color: AppColors.ink),
              ),
              Text(
                share.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);

  /// Part de l'anneau remplie, de 0 à 1.
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 13.0;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
        rect, 0, 2 * math.pi, false, paint..color = AppColors.lavender);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false,
        paint..color = AppColors.teal);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

/// Carte d'une séance du dernier jour joué : horaires, thèmes et
/// exercices. Un appui ouvre ses détails.
class LastSessionCard extends StatelessWidget {
  const LastSessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final TrainingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themes = session.categories.isEmpty
        ? const ['Sans catégorie']
        : session.categories.map((category) => category.nom).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.indigo, width: 6),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatTimeRange(
                          session.startTime, session.durationMinutes),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.indigo),
                ],
              ),
              if (formatOnSite(session) case final onSite?) ...[
                const SizedBox(height: 2),
                Text(onSite, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              _LabelWrap(labels: themes),
              if (session.exercises.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${session.exercises.length} exercice'
                  '${session.exercises.length > 1 ? 's' : ''}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                _LabelWrap(
                  labels: session.exercises
                      .map((exercise) => exercise.name)
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelWrap extends StatelessWidget {
  const _LabelWrap({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Chip(
            label: Text(label),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
      ],
    );
  }
}

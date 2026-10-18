import 'package:flutter/material.dart';

import '../services/session_store.dart';
import '../services/stats.dart';
import '../utils/format.dart';
import '../widgets/study_bar_chart.dart';

class StatsScreen extends StatefulWidget {
  final SessionStore store;
  const StatsScreen({super.key, required this.store});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  ChartRange _range = ChartRange.daily;
  int _page = 0; // 0 = most recent
  bool _cumulative = false;
  int? _selected; // tapped bar; null = latest bar

  void _setRange(ChartRange r) => setState(() {
        _range = r;
        _page = 0;
        _selected = null;
      });

  void _setPage(int p) => setState(() {
        _page = p;
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final now = DateTime.now();
          final today = dateOnly(now);
          final totals = widget.store.dailyTotals(now: now);

          final allTime = sumAll(totals);
          final weekStart = startOfWeek(today);
          final thisWeek = sumBetween(totals, weekStart, DateTime(weekStart.year, weekStart.month, weekStart.day + 7));
          final monthStart = startOfMonth(today);
          final thisMonth = sumBetween(totals, monthStart, DateTime(monthStart.year, monthStart.month + 1));

          final buckets = buildBuckets(totals, _range, _page, today);
          final averages = computeAverages(totals, today);

          // Bar heights: either each period's own total, or the running total so far.
          final values = <Duration>[];
          var running = sumBetween(totals, DateTime(1970), buckets.first.start);
          for (final b in buckets) {
            running += b.total;
            values.add(_cumulative ? running : b.total);
          }

          final selected = _selected ?? buckets.length - 1;
          final selBucket = buckets[selected];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // Summary cards
              Row(
                children: [
                  _SummaryCard(label: 'All time', value: allTime, icon: Icons.all_inclusive),
                  const SizedBox(width: 8),
                  _SummaryCard(label: 'This week', value: thisWeek, icon: Icons.view_week),
                  const SizedBox(width: 8),
                  _SummaryCard(label: 'This month', value: thisMonth, icon: Icons.calendar_month),
                ],
              ),
              const SizedBox(height: 20),

              // Averages (days with no study count as 0)
              Text('Average per day', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                averages.since == null
                    ? 'Log a session to start your averages.'
                    : 'Since ${formatLongDate(averages.since!)} · '
                        '${averages.dayCount} ${averages.dayCount == 1 ? 'day' : 'days'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AverageCard(
                    label: 'Weekdays',
                    detail: 'Mon–Fri',
                    value: averages.weekday,
                  ),
                  const SizedBox(width: 8),
                  _AverageCard(
                    label: 'Weekends',
                    detail: 'Sat–Sun',
                    value: averages.weekend,
                  ),
                  const SizedBox(width: 8),
                  _AverageCard(
                    label: 'Every day',
                    detail: 'All days',
                    value: averages.everyDay,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daily / Weekly / Monthly toggle
              SegmentedButton<ChartRange>(
                segments: const [
                  ButtonSegment(value: ChartRange.daily, label: Text('Daily')),
                  ButtonSegment(value: ChartRange.weekly, label: Text('Weekly')),
                  ButtonSegment(value: ChartRange.monthly, label: Text('Monthly')),
                ],
                selected: {_range},
                onSelectionChanged: (s) => _setRange(s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Cumulative'),
                    selected: _cumulative,
                    onSelected: (v) => setState(() => _cumulative = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Page navigation
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Earlier',
                    onPressed: () => _setPage(_page + 1),
                  ),
                  Expanded(
                    child: Text(pageTitle(buckets),
                        textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Later',
                    onPressed: _page == 0 ? null : () => _setPage(_page - 1),
                  ),
                ],
              ),

              // Selected bar readout
              Card(
                child: ListTile(
                  title: Text(bucketTitle(_range, selBucket)),
                  subtitle: _cumulative ? const Text('Running total up to here') : null,
                  trailing: Text(formatHoursMinutes(values[selected]),
                      style: theme.textTheme.titleLarge),
                ),
              ),
              const SizedBox(height: 12),

              StudyBarChart(
                hours: [for (final v in values) v.inSeconds / 3600],
                labels: [for (final b in buckets) bucketLabel(_range, b)],
                selected: selected,
                onSelect: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: 8),
              Text('Tap a bar to see its exact time.',
                  textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final Duration value;
  final IconData icon;

  const _SummaryCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatHoursMinutes(value),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  final String label;
  final String detail;
  final Duration? value; // null = no days of this kind yet
  final bool highlight;

  const _AverageCard({
    required this.label,
    required this.detail,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = highlight ? scheme.onPrimaryContainer : scheme.onSurface;

    return Expanded(
      child: Card(
        color: highlight ? scheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(label,
                  style: theme.textTheme.labelLarge?.copyWith(color: fg)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value == null ? '—' : formatHoursMinutes(value!),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600, color: fg),
                ),
              ),
              const SizedBox(height: 2),
              Text(detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

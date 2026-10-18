import 'package:flutter/material.dart';

import '../services/session_store.dart';
import '../utils/format.dart';
import '../widgets/session_editor.dart';

class CalendarScreen extends StatefulWidget {
  final SessionStore store;
  const CalendarScreen({super.key, required this.store});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first day of the month on screen
  late DateTime _selected;

  /// A day with this much study (or more) gets the strongest color.
  static const _fullColorHours = 4.0;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
  }

  void _changeMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToToday() {
    final today = dateOnly(DateTime.now());
    setState(() {
      _month = DateTime(today.year, today.month);
      _selected = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [TextButton(onPressed: _goToToday, child: const Text('Today'))],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final today = dateOnly(now);
          final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
          // Sunday-first grid: Sunday = 0 ... Saturday = 6
          final leadingBlanks = DateTime(_month.year, _month.month, 1).weekday % 7;
          final cellCount = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;

          var monthTotal = Duration.zero;
          for (var d = 1; d <= daysInMonth; d++) {
            monthTotal += store.totalOn(DateTime(_month.year, _month.month, d), now: now);
          }

          final selectedSessions = store.sessionsOn(_selected);
          final selectedTotal = store.totalOn(_selected, now: now);
          final selectedIsFuture = _selected.isAfter(today);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              // Month header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('${monthNames[_month.month - 1]} ${_month.year}',
                            style: theme.textTheme.titleLarge),
                        Text('Month total: ${formatHoursMinutes(monthTotal)}',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Weekday labels
              Row(
                children: [
                  for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Expanded(
                      child: Text(w,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Day grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cellCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, i) {
                  final dayNum = i - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
                  final day = DateTime(_month.year, _month.month, dayNum);
                  return _DayCell(
                    day: dayNum,
                    total: store.totalOn(day, now: now),
                    isToday: day == today,
                    isSelected: day == _selected,
                    isFuture: day.isAfter(today),
                    fullColorHours: _fullColorHours,
                    onTap: () => setState(() => _selected = day),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),

              // Selected day details
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(formatLongDate(_selected), style: theme.textTheme.titleMedium),
                subtitle: Text(selectedTotal == Duration.zero
                    ? 'No study logged'
                    : 'Studied ${formatHoursMinutes(selectedTotal)}'),
                trailing: selectedIsFuture
                    ? null
                    : FilledButton.tonalIcon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        onPressed: () =>
                            showSessionEditor(context, store: store, day: _selected),
                      ),
              ),
              if (_selected == today && store.isRunning)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.timer, color: theme.colorScheme.primary),
                  title: Text('Started ${formatTime(store.activeStart!)} – running now'),
                ),
              for (final s in selectedSessions)
                Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: theme.colorScheme.errorContainer,
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => store.delete(s.id),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.timer_outlined),
                    title: Text('${formatTime(s.start)} – ${formatTime(s.end)}'),
                    trailing: Text(formatHoursMinutes(s.duration)),
                    onTap: () => showSessionEditor(context,
                        store: store, day: _selected, existing: s),
                  ),
                ),
              if (selectedSessions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Tap a session to edit it, swipe left to delete.',
                      style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final Duration total;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final double fullColorHours;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.total,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.fullColorHours,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hours = total.inSeconds / 3600;
    final strength = (hours / fullColorHours).clamp(0.0, 1.0);
    final studied = total.inMinutes > 0;

    // More study = stronger color.
    final fill = studied
        ? scheme.primary.withValues(alpha: 0.18 + 0.72 * strength)
        : scheme.surfaceContainerHighest.withValues(alpha: isFuture ? 0.25 : 0.6);
    final textColor = studied && strength > 0.5 ? scheme.onPrimary : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: scheme.tertiary, width: 2.5)
              : isToday
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isFuture ? scheme.onSurface.withValues(alpha: 0.4) : textColor,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                studied ? formatCompact(total) : '',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

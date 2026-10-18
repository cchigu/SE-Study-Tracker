import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/session_store.dart';
import '../utils/format.dart';
import '../widgets/session_editor.dart';

class TimerScreen extends StatefulWidget {
  final SessionStore store;
  const TimerScreen({super.key, required this.store});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Redraw once a second so the clock moves. Elapsed time is always
    // computed from the saved start time, so it never drifts.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.store.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final running = store.isRunning;
        final current = running ? now.difference(store.activeStart!) : Duration.zero;
        final today = store.totalOn(now, now: now);
        final todaySessions = store.sessionsOn(now).reversed.toList();

        return Scaffold(
          appBar: AppBar(title: const Text('SE Exam Study Tracker')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              Text('Current session',
                  textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                formatClock(current),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor:
                          running ? theme.colorScheme.error : theme.colorScheme.primary,
                    ),
                    onPressed: running ? store.stop : store.start,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 64),
                        Text(running ? 'STOP' : 'START',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('Studied today'),
                  trailing: Text(formatHoursMinutes(today),
                      style: theme.textTheme.titleLarge),
                ),
              ),
              const SizedBox(height: 16),
              if (todaySessions.isNotEmpty) ...[
                Text("Today's sessions", style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final s in todaySessions)
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
                      onTap: () =>
                          showSessionEditor(context, store: store, day: s.day, existing: s),
                    ),
                  ),
                Text('Tap a session to edit it, swipe left to delete.',
                    style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../services/session_store.dart';

/// Placeholder until Milestone 3 (totals + charts) and 4 (averages).
class StatsScreen extends StatelessWidget {
  final SessionStore store;
  const StatsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Charts and averages are coming next.', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/session_store.dart';
import 'calendar_screen.dart';
import 'stats_screen.dart';
import 'timer_screen.dart';

/// The bottom-tab frame that holds the three main screens.
class HomeShell extends StatefulWidget {
  final SessionStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive, so switching tabs doesn't reset them.
      body: IndexedStack(
        index: _tab,
        children: [
          TimerScreen(store: widget.store),
          CalendarScreen(store: widget.store),
          StatsScreen(store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}

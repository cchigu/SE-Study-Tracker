import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/format.dart';
import 'session_store.dart';

/// Keeps a "Time studied today" notification up to date.
///
/// - Timer running: an ongoing notification whose clock counts up live
///   (Android draws the clock itself, so it keeps ticking even if the app
///   is closed).
/// - Timer stopped: a regular notification with today's total.
/// - Nothing studied today: no notification.
class StudyNotification {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1;
  static const _channelId = 'study_today';
  static const _channelName = 'Time studied today';
  static String? _lastShown;

  static Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_study'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    // Android 13+ asks the user once for permission to show notifications.
    // Not awaited, so the app opens while the prompt is up.
    unawaited(_plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission()
        .then((granted) => _lastShown = null)); // re-show once allowed
  }

  /// Call whenever the store changes. Only touches the notification when
  /// what it shows actually changes.
  static Future<void> sync(SessionStore store) async {
    final now = DateTime.now();
    final today = dateOnly(now);

    // Study already saved for today (not counting the running timer).
    final saved = store.sessionsOn(today).fold(Duration.zero, (a, s) => a + s.duration);
    final active = store.activeStart;

    if (active != null) {
      // The running timer's part of today starts at midnight if it began yesterday.
      final runStart = active.isBefore(today) ? today : active;
      // Point the counting clock back by what was already saved, so it shows
      // today's total, not just this session.
      final clockBase = runStart.subtract(saved);
      final key = 'run:${clockBase.millisecondsSinceEpoch}';
      if (key == _lastShown) return;
      _lastShown = key;

      await _plugin.show(
        _id,
        'Time studied today',
        'Timer running since ${formatTime(active)}',
        NotificationDetails(
          android: _android(
            ongoing: true,
            usesChronometer: true,
            when: clockBase.millisecondsSinceEpoch,
            subText: _shortDate(today),
          ),
          iOS: const DarwinNotificationDetails(presentSound: false),
        ),
      );
      return;
    }

    if (saved == Duration.zero) {
      if (_lastShown == 'none') return;
      _lastShown = 'none';
      await _plugin.cancel(_id);
      return;
    }

    final key = 'stopped:${today.toIso8601String()}:${saved.inMinutes}';
    if (key == _lastShown) return;
    _lastShown = key;

    await _plugin.show(
      _id,
      'Time studied today: ${formatHoursMinutes(saved)}',
      'Timer stopped. Tap to open the app.',
      NotificationDetails(
        android: _android(
          ongoing: false,
          usesChronometer: false,
          when: now.millisecondsSinceEpoch,
          subText: _shortDate(today),
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  static AndroidNotificationDetails _android({
    required bool ongoing,
    required bool usesChronometer,
    required int when,
    required String subText,
  }) =>
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Shows how long you have studied today',
        icon: 'ic_stat_study',
        color: Colors.indigo,
        importance: Importance.low, // no sound or pop-up, just sits in the bar
        priority: Priority.low,
        ongoing: ongoing,
        autoCancel: false,
        onlyAlertOnce: true,
        silent: true,
        showWhen: true,
        usesChronometer: usesChronometer,
        when: when,
        subText: subText,
        category: AndroidNotificationCategory.stopwatch,
      );

  static String _shortDate(DateTime d) =>
      '${weekdayNames[d.weekday - 1].substring(0, 3)}, '
      '${monthNames[d.month - 1].substring(0, 3)} ${d.day}';
}

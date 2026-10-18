import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_session.dart';

/// Holds every study session plus the currently running timer (if any).
/// Milestone 1: saved on the phone with shared_preferences.
/// Milestone 5 will swap the save/load for Firestore — the rest of the app
/// only talks to this class, so nothing else has to change.
class SessionStore extends ChangeNotifier {
  static const _sessionsKey = 'sessions_v1';
  static const _activeStartKey = 'active_start_v1';

  final List<StudySession> _sessions = [];
  DateTime? _activeStart;
  late SharedPreferences _prefs;

  List<StudySession> get sessions => List.unmodifiable(_sessions);
  bool get isRunning => _activeStart != null;
  DateTime? get activeStart => _activeStart;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs.getString(_sessionsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _sessions
        ..clear()
        ..addAll(list.map((e) => StudySession.fromJson(e as Map<String, dynamic>)));
    }

    // If the app was closed/killed while the timer was running, pick it back up.
    final active = _prefs.getString(_activeStartKey);
    _activeStart = active == null ? null : DateTime.parse(active);

    notifyListeners();
  }

  Future<void> start() async {
    if (isRunning) return;
    _activeStart = DateTime.now();
    await _prefs.setString(_activeStartKey, _activeStart!.toIso8601String());
    notifyListeners();
  }

  Future<void> stop() async {
    if (!isRunning) return;
    final end = DateTime.now();
    // Ignore accidental taps shorter than 5 seconds.
    if (end.difference(_activeStart!).inSeconds >= 5) {
      _sessions.addAll(StudySession.splitByDay(_activeStart!, end));
      await _saveSessions();
    }
    _activeStart = null;
    await _prefs.remove(_activeStartKey);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _saveSessions();
    notifyListeners();
  }

  /// Saved sessions for one calendar day, oldest first.
  List<StudySession> sessionsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _sessions.where((s) => s.day == d).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Total for a day, including the part of a running timer that falls on it.
  Duration totalOn(DateTime day, {DateTime? now}) {
    var total = sessionsOn(day).fold(Duration.zero, (sum, s) => sum + s.duration);
    if (_activeStart != null) {
      final n = now ?? DateTime.now();
      for (final piece in StudySession.splitByDay(_activeStart!, n)) {
        if (piece.day == DateTime(day.year, day.month, day.day)) {
          total += piece.duration;
        }
      }
    }
    return total;
  }

  Future<void> _saveSessions() =>
      _prefs.setString(_sessionsKey, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
}

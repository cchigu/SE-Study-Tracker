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

  /// Add a session by hand (e.g. forgot to hit Start).
  Future<void> addSession(DateTime start, DateTime end) async {
    _sessions.addAll(StudySession.splitByDay(start, end));
    await _saveSessions();
    notifyListeners();
  }

  /// Change the start/end of an existing session.
  Future<void> updateSession(String id, DateTime start, DateTime end) async {
    _sessions.removeWhere((s) => s.id == id);
    _sessions.addAll(StudySession.splitByDay(start, end));
    await _saveSessions();
    notifyListeners();
  }

  /// True if [start]–[end] overlaps a saved session (other than [ignoreId])
  /// or the timer that's running right now.
  bool overlaps(DateTime start, DateTime end, {String? ignoreId}) {
    for (final s in _sessions) {
      if (s.id == ignoreId) continue;
      if (start.isBefore(s.end) && end.isAfter(s.start)) return true;
    }
    if (_activeStart != null) {
      if (start.isBefore(DateTime.now()) && end.isAfter(_activeStart!)) return true;
    }
    return false;
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

  /// Study time per calendar day (local midnight → total), including the
  /// running timer. Days with no study are left out.
  Map<DateTime, Duration> dailyTotals({DateTime? now}) {
    final totals = <DateTime, Duration>{};
    void addPiece(StudySession s) =>
        totals[s.day] = (totals[s.day] ?? Duration.zero) + s.duration;

    for (final s in _sessions) {
      addPiece(s);
    }
    if (_activeStart != null) {
      StudySession.splitByDay(_activeStart!, now ?? DateTime.now()).forEach(addPiece);
    }
    return totals;
  }

  Future<void> _saveSessions() =>
      _prefs.setString(_sessionsKey, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
}

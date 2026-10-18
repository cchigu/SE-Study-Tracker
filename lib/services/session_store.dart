import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_session.dart';

/// Holds every study session plus the currently running timer (if any).
///
/// Signed out: everything lives on the phone (shared_preferences).
/// Signed in: Firestore is the source of truth, under
///   users/{uid}                 { activeStart: "2026-10-18T09:00:00.000" | null }
///   users/{uid}/sessions/{id}   { id, start, end }
/// A copy is still kept on the phone, and Firestore's offline cache means
/// it keeps working with no signal and syncs when the connection is back.
class SessionStore extends ChangeNotifier {
  static const _sessionsKey = 'sessions_v1';
  static const _activeStartKey = 'active_start_v1';

  final List<StudySession> _sessions = [];
  DateTime? _activeStart;
  late SharedPreferences _prefs;

  String? _uid;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  List<StudySession> get sessions => List.unmodifiable(_sessions);
  bool get isRunning => _activeStart != null;
  DateTime? get activeStart => _activeStart;
  bool get isSignedIn => _uid != null;

  // ---------------------------------------------------------------- loading

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

  // ------------------------------------------------------------ cloud sync

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _sessionsCol =>
      _userDoc.collection('sessions');

  /// Called whenever someone signs in or out (uid = null when signed out).
  Future<void> attachUser(String? uid) async {
    if (uid == _uid) return;

    await _sessionsSub?.cancel();
    await _userSub?.cancel();
    _sessionsSub = null;
    _userSub = null;

    final wasSignedIn = _uid != null;
    _uid = uid;

    if (uid == null) {
      if (wasSignedIn) {
        // Signed out: the sessions are safe in the account, so take them off
        // this phone. A running timer is kept so you don't lose it.
        _sessions.clear();
        await _saveLocal();
        notifyListeners();
      }
      return;
    }

    // Signed in: push anything logged on this phone up to the account.
    // Session ids are unique, so uploading the same one twice is harmless.
    final batch = FirebaseFirestore.instance.batch();
    for (final s in _sessions) {
      batch.set(_sessionsCol.doc(s.id), s.toJson());
    }
    if (_activeStart != null) {
      batch.set(_userDoc, {'activeStart': _activeStart!.toIso8601String()},
          SetOptions(merge: true));
    }
    // Not awaited on purpose: with no signal this would wait until it's back
    // online, but Firestore applies it to its local cache right away.
    unawaited(batch.commit());

    // From now on, follow the account.
    _sessionsSub = _sessionsCol.snapshots().listen((snap) {
      _sessions
        ..clear()
        ..addAll(snap.docs.map((d) => StudySession.fromJson(d.data())));
      _saveLocal();
      notifyListeners();
    }, onError: (Object e) => debugPrint('Session sync error: $e'));

    _userSub = _userDoc.snapshots().listen((doc) {
      final v = doc.data()?['activeStart'] as String?;
      _activeStart = v == null ? null : DateTime.parse(v);
      _saveLocal();
      notifyListeners();
    }, onError: (Object e) => debugPrint('Timer sync error: $e'));
  }

  /// Mirror a change to Firestore when signed in. Does nothing when signed out.
  void _cloud(void Function(WriteBatch batch) build) {
    if (_uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    build(batch);
    unawaited(batch.commit().catchError((Object e) => debugPrint('Sync write error: $e')));
  }

  // ------------------------------------------------------------- timer

  Future<void> start() async {
    if (isRunning) return;
    _activeStart = DateTime.now();
    await _saveLocal();
    _cloud((b) => b.set(_userDoc, {'activeStart': _activeStart!.toIso8601String()},
        SetOptions(merge: true)));
    notifyListeners();
  }

  Future<void> stop() async {
    if (!isRunning) return;
    final end = DateTime.now();
    final pieces = <StudySession>[];
    // Ignore accidental taps shorter than 5 seconds.
    if (end.difference(_activeStart!).inSeconds >= 5) {
      pieces.addAll(StudySession.splitByDay(_activeStart!, end));
      _sessions.addAll(pieces);
    }
    _activeStart = null;
    await _saveLocal();
    _cloud((b) {
      for (final p in pieces) {
        b.set(_sessionsCol.doc(p.id), p.toJson());
      }
      b.set(_userDoc, {'activeStart': null}, SetOptions(merge: true));
    });
    notifyListeners();
  }

  // ------------------------------------------------------- editing sessions

  /// Add a session by hand (e.g. forgot to hit Start).
  Future<void> addSession(DateTime start, DateTime end) async {
    final pieces = StudySession.splitByDay(start, end);
    _sessions.addAll(pieces);
    await _saveLocal();
    _cloud((b) {
      for (final p in pieces) {
        b.set(_sessionsCol.doc(p.id), p.toJson());
      }
    });
    notifyListeners();
  }

  /// Change the start/end of an existing session.
  Future<void> updateSession(String id, DateTime start, DateTime end) async {
    final pieces = StudySession.splitByDay(start, end);
    _sessions.removeWhere((s) => s.id == id);
    _sessions.addAll(pieces);
    await _saveLocal();
    _cloud((b) {
      b.delete(_sessionsCol.doc(id));
      for (final p in pieces) {
        b.set(_sessionsCol.doc(p.id), p.toJson());
      }
    });
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _saveLocal();
    _cloud((b) => b.delete(_sessionsCol.doc(id)));
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

  // ---------------------------------------------------------------- queries

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

  // ----------------------------------------------------------- local save

  Future<void> _saveLocal() async {
    await _prefs.setString(
        _sessionsKey, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    if (_activeStart == null) {
      await _prefs.remove(_activeStartKey);
    } else {
      await _prefs.setString(_activeStartKey, _activeStart!.toIso8601String());
    }
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}

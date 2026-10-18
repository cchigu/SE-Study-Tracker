/// One continuous block of studying. Always stays inside a single calendar day
/// (sessions that cross midnight get split — see [splitByDay]).
class StudySession {
  final String id;
  final DateTime start;
  final DateTime end;

  StudySession({required this.id, required this.start, required this.end});

  Duration get duration => end.difference(start);

  /// The calendar day this session belongs to (local midnight).
  DateTime get day => DateTime(start.year, start.month, start.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
      );

  /// Turns one start→stop span into one session per calendar day.
  /// e.g. 11:30 PM → 1:00 AM becomes 30 min today + 1 h tomorrow.
  static List<StudySession> splitByDay(DateTime start, DateTime end) {
    final pieces = <StudySession>[];
    final baseId = start.microsecondsSinceEpoch.toString();
    var cursor = start;
    var i = 0;
    while (cursor.isBefore(end)) {
      final nextMidnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final pieceEnd = end.isBefore(nextMidnight) ? end : nextMidnight;
      pieces.add(StudySession(id: '$baseId-$i', start: cursor, end: pieceEnd));
      cursor = pieceEnd;
      i++;
    }
    return pieces;
  }
}

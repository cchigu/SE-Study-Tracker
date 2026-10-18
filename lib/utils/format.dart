String _two(int n) => n.toString().padLeft(2, '0');

/// 01:23:45
String formatClock(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

/// 2h 05m  /  45m
String formatHoursMinutes(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${_two(m)}m' : '${m}m';
}

/// 9:05 PM
String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _two(int n) => n.toString().padLeft(2, '0');

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// 01:23:45
String formatClock(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';

/// 2h 05m  /  45m
String formatHoursMinutes(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${_two(m)}m' : '${m}m';
}

/// Short version for calendar cells: 2h05 / 45m
String formatCompact(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h${_two(m)}' : '${m}m';
}

/// 9:05 PM
String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Sunday, October 18
String formatLongDate(DateTime d) =>
    '${weekdayNames[d.weekday - 1]}, ${monthNames[d.month - 1]} ${d.day}';

/// Midnight at the start of [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

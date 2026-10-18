import '../utils/format.dart';

enum ChartRange { daily, weekly, monthly }

/// One bar on the chart: a day, a week, or a month.
class Bucket {
  final DateTime start; // inclusive, local midnight
  final DateTime end; // exclusive
  final Duration total;

  Bucket(this.start, this.end, this.total);
}

/// How many bars each range shows per page.
int barsPerPage(ChartRange r) => switch (r) {
      ChartRange.daily => 14,
      ChartRange.weekly => 12,
      ChartRange.monthly => 12,
    };

/// Sunday that starts the week containing [d].
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - d.weekday % 7);

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

/// Sum of [totals] for days in [start, end).
Duration sumBetween(Map<DateTime, Duration> totals, DateTime start, DateTime end) {
  var sum = Duration.zero;
  totals.forEach((day, t) {
    if (!day.isBefore(start) && day.isBefore(end)) sum += t;
  });
  return sum;
}

Duration sumAll(Map<DateTime, Duration> totals) =>
    totals.values.fold(Duration.zero, (a, b) => a + b);

/// The bars for one page of the chart, oldest first.
/// [page] 0 = the most recent period, 1 = the one before it, etc.
List<Bucket> buildBuckets(
  Map<DateTime, Duration> totals,
  ChartRange range,
  int page,
  DateTime today,
) {
  final n = barsPerPage(range);
  final buckets = <Bucket>[];

  for (var i = n - 1; i >= 0; i--) {
    final steps = page * n + i; // how many periods back from the current one
    late DateTime start;
    late DateTime end;
    switch (range) {
      case ChartRange.daily:
        start = DateTime(today.year, today.month, today.day - steps);
        end = DateTime(start.year, start.month, start.day + 1);
      case ChartRange.weekly:
        final thisWeek = startOfWeek(today);
        start = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * steps);
        end = DateTime(start.year, start.month, start.day + 7);
      case ChartRange.monthly:
        start = DateTime(today.year, today.month - steps);
        end = DateTime(start.year, start.month + 1);
    }
    buckets.add(Bucket(start, end, sumBetween(totals, start, end)));
  }
  return buckets;
}

/// Label under a bar.
String bucketLabel(ChartRange r, Bucket b) => switch (r) {
      ChartRange.daily => '${'MTWTFSS'[b.start.weekday - 1]}\n${b.start.day}',
      ChartRange.weekly => '${b.start.month}/${b.start.day}',
      ChartRange.monthly => monthNames[b.start.month - 1].substring(0, 3),
    };

/// Longer description of a bar, shown when it's tapped.
String bucketTitle(ChartRange r, Bucket b) {
  String md(DateTime d) => '${monthNames[d.month - 1].substring(0, 3)} ${d.day}';
  return switch (r) {
    ChartRange.daily => formatLongDate(b.start),
    ChartRange.weekly => 'Week of ${md(b.start)}',
    ChartRange.monthly => '${monthNames[b.start.month - 1]} ${b.start.year}',
  };
}

/// Date span covered by a page, e.g. "Oct 5 – Oct 18, 2026".
String pageTitle(List<Bucket> buckets) {
  final first = buckets.first.start;
  final last = buckets.last.end.subtract(const Duration(hours: 12)); // last day inside
  String md(DateTime d) => '${monthNames[d.month - 1].substring(0, 3)} ${d.day}';
  final years = first.year == last.year ? '${last.year}' : '${first.year}–${last.year}';
  return '${md(first)} – ${md(last)}, $years';
}

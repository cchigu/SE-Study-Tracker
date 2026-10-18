import 'package:flutter/material.dart';

/// A simple bar chart of hours. Tap a bar to select it.
class StudyBarChart extends StatelessWidget {
  final List<double> hours;
  final List<String> labels;
  final int? selected;
  final ValueChanged<int> onSelect;
  final double height;

  const StudyBarChart({
    super.key,
    required this.hours,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.height = 240,
  });

  /// Picks a tidy gridline step so there are at most 4 lines.
  static double _niceStep(double max) {
    const steps = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0];
    for (final s in steps) {
      if (max / s <= 4) return s;
    }
    return 2000;
  }

  static String _hoursLabel(double h) =>
      h == h.roundToDouble() ? '${h.round()}h' : '${h.toStringAsFixed(1)}h';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    final maxValue = hours.fold<double>(0, (a, b) => b > a ? b : a);
    final step = _niceStep(maxValue <= 0 ? 1 : maxValue);
    final lineCount = ((maxValue <= 0 ? 1 : maxValue) / step).ceil();
    final yMax = step * lineCount;

    const axisWidth = 36.0;
    const labelHeight = 33.0;
    const topPad = 8.0;
    final plotHeight = height - labelHeight - topPad;

    double yFor(double value) => topPad + plotHeight - plotHeight * (value / yMax);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          // Y-axis labels
          SizedBox(
            width: axisWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i <= lineCount; i++)
                  Positioned(
                    right: 6,
                    top: yFor(i * step) - 7,
                    child: Text(_hoursLabel(i * step), style: textStyle),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: topPad + plotHeight + 1,
                  child: Stack(
                    children: [
                      // Gridlines
                      for (var i = 0; i <= lineCount; i++)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: yFor(i * step),
                          child: Container(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: i == 0 ? 1 : 0.5),
                          ),
                        ),
                      // Bars
                      Positioned.fill(
                        bottom: 1,
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var j = 0; j < hours.length; j++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onSelect(j),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.62,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOut,
                                      height: plotHeight * (hours[j] / yMax),
                                      decoration: BoxDecoration(
                                        color: j == selected
                                            ? scheme.tertiary
                                            : scheme.primary,
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
                // X-axis labels
                SizedBox(
                  height: labelHeight,
                  child: Row(
                    children: [
                      for (var j = 0; j < labels.length; j++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(j),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  labels[j],
                                  textAlign: TextAlign.center,
                                  style: textStyle?.copyWith(
                                    fontWeight:
                                        j == selected ? FontWeight.bold : FontWeight.normal,
                                    color: j == selected ? scheme.tertiary : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/study_session.dart';
import '../services/session_store.dart';
import '../utils/format.dart';

/// Opens a dialog to add a session on [day], or edit [existing] if given.
Future<void> showSessionEditor(
  BuildContext context, {
  required SessionStore store,
  required DateTime day,
  StudySession? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SessionEditorDialog(store: store, day: dateOnly(day), existing: existing),
  );
}

class _SessionEditorDialog extends StatefulWidget {
  final SessionStore store;
  final DateTime day;
  final StudySession? existing;

  const _SessionEditorDialog({required this.store, required this.day, this.existing});

  @override
  State<_SessionEditorDialog> createState() => _SessionEditorDialogState();
}

class _SessionEditorDialogState extends State<_SessionEditorDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _start = TimeOfDay.fromDateTime(e.start);
      _end = TimeOfDay.fromDateTime(e.end);
    } else {
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  DateTime _onDay(TimeOfDay t) =>
      DateTime(widget.day.year, widget.day.month, widget.day.day, t.hour, t.minute);

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Started at' : 'Ended at',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final start = _onDay(_start);
    final end = _onDay(_end);

    if (!end.isAfter(start)) {
      setState(() => _error = 'End time has to be after the start time.');
      return;
    }
    if (end.isAfter(DateTime.now())) {
      setState(() => _error = "That session ends in the future.");
      return;
    }
    if (widget.store.overlaps(start, end, ignoreId: widget.existing?.id)) {
      setState(() => _error = 'That overlaps another session on this day.');
      return;
    }

    final nav = Navigator.of(context);
    if (_isEdit) {
      await widget.store.updateSession(widget.existing!.id, start, end);
    } else {
      await widget.store.addSession(start, end);
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await widget.store.delete(widget.existing!.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final length = _onDay(_end).difference(_onDay(_start));
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEdit ? 'Edit session' : 'Add session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatLongDate(widget.day), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Start'),
            trailing: Text(_start.format(context), style: theme.textTheme.titleMedium),
            onTap: () => _pick(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_rounded),
            title: const Text('End'),
            trailing: Text(_end.format(context), style: theme.textTheme.titleMedium),
            onTap: () => _pick(isStart: false),
          ),
          if (length > Duration.zero)
            Text('Length: ${formatHoursMinutes(length)}', style: theme.textTheme.bodySmall),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

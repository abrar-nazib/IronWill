import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/local_db.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Bottom-sheet editor for a [Subject] and its [SubjectBlock]s.
///
/// Pass `existing` to edit; omit to create. The sheet handles:
///   * subject name
///   * the block list (add / edit / delete each scheduled time slot)
///   * the schedule TTL (the "Repeat next week" button extends `expiresAt`)
///   * delete subject (cascades to its blocks via the schema FK)
Future<void> showSubjectEditSheet(BuildContext context, {Subject? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (ctx) => _SubjectEditSheet(existing: existing),
  );
}

class _SubjectEditSheet extends StatefulWidget {
  final Subject? existing;
  const _SubjectEditSheet({this.existing});

  @override
  State<_SubjectEditSheet> createState() => _SubjectEditSheetState();
}

class _SubjectEditSheetState extends State<_SubjectEditSheet> {
  late final TextEditingController _name;
  late DateTime _expiresAt;
  late List<SubjectBlockDraft> _blocks;
  String? _existingId;
  List<SubjectBlock> _existingBlocks = const [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _existingId = s?.id;
    _existingBlocks = s?.blocks ?? const [];
    _name = TextEditingController(text: s?.name ?? '');
    _expiresAt = s?.expiresAt ??
        DateTime.now().add(const Duration(days: LocalDb.defaultExpiryDays));
    _blocks = (s?.blocks ?? const [])
        .map((b) => SubjectBlockDraft(
              dayOfWeek: b.dayOfWeek,
              start: b.start,
              end: b.end,
              pomodoroEnabled: b.pomodoroEnabled,
              pomodoroPercent: b.pomodoroPercent,
            ))
        .toList();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 3),
    ));
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Two blocks overlap if they share a weekday AND their minute ranges
  /// intersect. Equal touchpoints (one ends 9:00, next starts 9:00) are OK.
  SubjectBlockDraft? _findInternalOverlap() {
    for (var i = 0; i < _blocks.length; i++) {
      for (var j = i + 1; j < _blocks.length; j++) {
        final a = _blocks[i];
        final b = _blocks[j];
        if (a.dayOfWeek != b.dayOfWeek) continue;
        final aStart = _toMin(a.start);
        final aEnd = _toMin(a.end);
        final bStart = _toMin(b.start);
        final bEnd = _toMin(b.end);
        if (aStart < bEnd && bStart < aEnd) return b;
      }
    }
    return null;
  }

  /// Search every other subject's blocks for an overlap with any block in
  /// the local list. Returns the first conflict found.
  ({Subject subject, SubjectBlock block})? _findCrossSubjectOverlap(
      List<Subject> all) {
    for (final s in all) {
      if (s.id == _existingId) continue;
      for (final other in s.blocks) {
        for (final mine in _blocks) {
          if (other.dayOfWeek != mine.dayOfWeek) continue;
          final mineStart = _toMin(mine.start);
          final mineEnd = _toMin(mine.end);
          final otherStart = other.startMinute;
          final otherEnd = other.endMinute;
          if (mineStart < otherEnd && otherStart < mineEnd) {
            return (subject: s, block: other);
          }
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showError('Give the subject a name.');
      return;
    }
    // Drop focus so the soft keyboard hides as the sheet pops, instead of
    // hanging around on the onboarding page underneath and forcing the
    // user to dismiss it manually.
    FocusScope.of(context).unfocus();
    for (final b in _blocks) {
      if (_toMin(b.end) <= _toMin(b.start)) {
        _showError('Each block must end after its start time.');
        return;
      }
    }
    final internal = _findInternalOverlap();
    if (internal != null) {
      _showError(
          'Two blocks under this subject overlap on ${_weekdayName(internal.dayOfWeek)}.');
      return;
    }
    final svc = AppServices.of(context);
    final cross = _findCrossSubjectOverlap(svc.subjects.all.value);
    if (cross != null) {
      _showError(
          'Overlaps with "${cross.subject.name}" on ${_weekdayName(cross.block.dayOfWeek)}.');
      return;
    }

    if (_isEditing) {
      final id = _existingId!;
      await svc.subjects.update(widget.existing!.copyWith(
        name: _name.text.trim(),
        expiresAt: _expiresAt,
      ));
      // Reconcile blocks: delete removed, update changed, add new. The draft
      // list isn't tied 1:1 to existing block ids, so we treat it as a
      // replacement: drop everything and re-add. Simple and correct; the
      // table is small.
      for (final b in _existingBlocks) {
        await svc.subjects.deleteBlock(b.id);
      }
      for (final b in _blocks) {
        await svc.subjects.addBlock(id, b);
      }
    } else {
      await svc.subjects.create(SubjectDraft(
        name: _name.text.trim(),
        expiresAt: _expiresAt,
        blocks: _blocks,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addBlock() async {
    final created = await showModalBottomSheet<List<SubjectBlockDraft>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      builder: (_) => _BlockEditorSheet(),
    );
    if (created != null && created.isNotEmpty) {
      setState(() => _blocks.addAll(created));
    }
  }

  Future<void> _editBlock(int index) async {
    final updated = await showModalBottomSheet<List<SubjectBlockDraft>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      builder: (_) => _BlockEditorSheet(initial: _blocks[index]),
    );
    if (updated != null && updated.isNotEmpty) {
      setState(() {
        // Editing replaces the original; if the user picked multiple days
        // we splay it into one block per day.
        _blocks.removeAt(index);
        _blocks.insertAll(index, updated);
      });
    }
  }

  Future<void> _pickExpiresAt() async {
    // Custom calendar modal instead of the system date picker so each
    // cell can carry a "blocks scheduled on this weekday" count derived
    // from the current draft. Helps the user see coverage at a glance
    // before committing to an expiry date.
    final blocksByDow = <int, int>{};
    for (final b in _blocks) {
      blocksByDow[b.dayOfWeek] = (blocksByDow[b.dayOfWeek] ?? 0) + 1;
    }
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      builder: (_) => _ExpiryCalendarSheet(
        initial: _expiresAt,
        blocksByDow: blocksByDow,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  void _repeatNextWeek() {
    final today = DateTime.now();
    final base = _expiresAt.isBefore(today) ? today : _expiresAt;
    setState(() {
      _expiresAt = base.add(const Duration(days: LocalDb.defaultExpiryDays));
    });
  }

  /// Shrink the TTL by 7 days. Floors at today (no point letting users pick a
  /// past date through this button; they can still pick any date via the
  /// calendar tap if they want history rewriting).
  void _shrinkOneWeek() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final candidate = _expiresAt.subtract(const Duration(days: 7));
    setState(() {
      _expiresAt = candidate.isBefore(todayDate) ? todayDate : candidate;
    });
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final svc = AppServices.of(context);
    if (_existingId != null) {
      await svc.subjects.delete(_existingId!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final daysLeft = DateTime(_expiresAt.year, _expiresAt.month, _expiresAt.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final canAddBlock = daysLeft > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.m, Sp.md, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(R.pill),
                  ),
                ),
              ),
              const SizedBox(height: Sp.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit subject' : 'New subject',
                      style: AppText.headline.copyWith(color: t.ink),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: Sp.md),
              Text('SUBJECT NAME',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              TextField(
                controller: _name,
                autofocus: !_isEditing,
                style: AppText.body.copyWith(color: t.ink, fontSize: 16),
                decoration: const InputDecoration(hintText: 'Mathematics'),
              ),
              const SizedBox(height: Sp.lg),
              _ExpiresRow(
                expiresAt: _expiresAt,
                onPick: _pickExpiresAt,
                onRepeat: _repeatNextWeek,
                onShrink: _shrinkOneWeek,
              ),
              const SizedBox(height: Sp.lg),
              Row(
                children: [
                  Text('BLOCKS',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: t.inkMuted)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: canAddBlock ? _addBlock : null,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add block'),
                  ),
                ],
              ),
              if (!canAddBlock) ...[
                const SizedBox(height: Sp.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Sp.s),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(R.s),
                    border: Border.all(color: t.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.triangleAlert,
                          color: t.accent, size: IconSize.s),
                      const SizedBox(width: Sp.s),
                      Expanded(
                        child: Text(
                          'Schedule has expired. Extend the date above before adding blocks.',
                          style: AppText.label
                              .copyWith(color: t.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Sp.s),
              if (_blocks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(R.s),
                    border: Border.all(color: t.divider),
                  ),
                  child: Text(
                    'Add at least one block (e.g., Mon 9:00–10:30) so reminders fire.',
                    style: AppText.label.copyWith(color: t.inkMuted),
                  ),
                ),
              for (var i = 0; i < _blocks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.s),
                  child: _BlockRow(
                    draft: _blocks[i],
                    onTap: () => _editBlock(i),
                    onDelete: () => setState(() => _blocks.removeAt(i)),
                  ),
                ),
              const SizedBox(height: Sp.x3l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Save changes' : 'Create subject'),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: Sp.s),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _delete,
                    child: const Text('Delete subject'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiresRow extends StatelessWidget {
  final DateTime expiresAt;
  final VoidCallback onPick;
  final VoidCallback onRepeat;
  final VoidCallback onShrink;
  const _ExpiresRow({
    required this.expiresAt,
    required this.onPick,
    required this.onRepeat,
    required this.onShrink,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final daysLeft = DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final dateLabel = DateFormat('EEE, d MMM').format(expiresAt);
    final hint = daysLeft >= 0
        ? '$daysLeft day${daysLeft == 1 ? '' : 's'} left on this schedule'
        : 'Expired ${-daysLeft} day${daysLeft == -1 ? '' : 's'} ago';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCHEDULE EXPIRES',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.inkMuted)),
        const SizedBox(height: Sp.s),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(R.s),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Sp.md, vertical: Sp.md),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: t.divider),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, color: t.ink, size: IconSize.m),
                const SizedBox(width: Sp.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateLabel,
                          style: AppText.bodyStrong.copyWith(color: t.ink)),
                      Text(hint,
                          style: AppText.label.copyWith(color: t.inkMuted)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight,
                    color: t.inkMuted, size: IconSize.s),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sp.s),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShrink,
                icon: const Icon(LucideIcons.minus, size: 16),
                label: const Text('-1 week'),
              ),
            ),
            const SizedBox(width: Sp.s),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRepeat,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('+1 week'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  final SubjectBlockDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _BlockRow({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final time =
        '${_fmt(draft.start)} – ${_fmt(draft.end)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(R.s),
                border: Border.all(color: t.divider),
              ),
              alignment: Alignment.center,
              child: Text(
                _weekdayName(draft.dayOfWeek).substring(0, 3),
                style: AppText.label.copyWith(color: t.ink),
              ),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time, style: AppText.bodyStrong.copyWith(color: t.ink)),
                  if (draft.pomodoroEnabled)
                    Text('Pomodoro ${draft.pomodoroPercent}%',
                        style:
                            AppText.label.copyWith(color: t.accent, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, color: t.inkMuted, size: IconSize.s),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inner sheet that edits a single [SubjectBlockDraft]. Returns the updated
/// draft on save, null on cancel.
class _BlockEditorSheet extends StatefulWidget {
  final SubjectBlockDraft? initial;
  const _BlockEditorSheet({this.initial});

  @override
  State<_BlockEditorSheet> createState() => _BlockEditorSheetState();
}

enum _BlockMode { weekdays, everyday, weekends, custom }

class _BlockEditorSheetState extends State<_BlockEditorSheet> {
  /// Multi-select across weekdays: picking Mon and Wed means the editor
  /// returns two blocks with the same start/end/pomodoro settings, one per
  /// chosen day. Editing an existing block starts with that single day
  /// selected.
  late Set<int> _days;
  late _BlockMode _mode;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _pomodoroEnabled;
  late int _pomodoroPercent;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i == null) {
      // New blocks default to Weekdays. Most users want a M-F study/work
      // schedule; if they need every day or weekends-only the chips are one
      // tap away.
      _mode = _BlockMode.weekdays;
      _days = {1, 2, 3, 4, 5};
    } else {
      _days = {i.dayOfWeek};
      _mode = _BlockMode.custom;
    }
    _start = i?.start ?? const TimeOfDay(hour: 9, minute: 0);
    _end = i?.end ?? const TimeOfDay(hour: 10, minute: 0);
    _pomodoroEnabled = i?.pomodoroEnabled ?? false;
    _pomodoroPercent = i?.pomodoroPercent ?? 15;
  }

  void _setMode(_BlockMode m) {
    setState(() {
      _mode = m;
      switch (m) {
        case _BlockMode.weekdays:
          _days = {1, 2, 3, 4, 5};
          break;
        case _BlockMode.everyday:
          _days = {1, 2, 3, 4, 5, 6, 7};
          break;
        case _BlockMode.weekends:
          _days = {6, 7};
          break;
        case _BlockMode.custom:
          // Leave whatever was selected. If empty, seed with Monday so the
          // user can see the picker react.
          if (_days.isEmpty) _days = {1};
          break;
      }
    });
  }

  void _toggleDay(int d) {
    setState(() {
      if (_days.contains(d)) {
        _days.remove(d);
      } else {
        _days.add(d);
      }
      // Manual day toggling means the user is in custom mode now.
      _mode = _BlockMode.custom;
    });
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  void _save() {
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pick at least one weekday.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    if (_toMin(_end) <= _toMin(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('End time must be after start time.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    final out = (_days.toList()..sort())
        .map((d) => SubjectBlockDraft(
              dayOfWeek: d,
              start: _start,
              end: _end,
              pomodoroEnabled: _pomodoroEnabled,
              pomodoroPercent: _pomodoroPercent,
            ))
        .toList();
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.m, Sp.md, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(R.pill),
                  ),
                ),
              ),
              const SizedBox(height: Sp.md),
              Text(widget.initial == null ? 'New block' : 'Edit block',
                  style: AppText.headline.copyWith(color: t.ink)),
              const SizedBox(height: Sp.lg),
              Text('WEEKDAYS',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Weekdays',
                      selected: _mode == _BlockMode.weekdays,
                      onTap: () => _setMode(_BlockMode.weekdays),
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: _ModeChip(
                      label: 'Every day',
                      selected: _mode == _BlockMode.everyday,
                      onTap: () => _setMode(_BlockMode.everyday),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.s),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Weekends',
                      selected: _mode == _BlockMode.weekends,
                      onTap: () => _setMode(_BlockMode.weekends),
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: _ModeChip(
                      label: 'Custom',
                      selected: _mode == _BlockMode.custom,
                      onTap: () => _setMode(_BlockMode.custom),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.s),
              Text('Tap any day to fine-tune the selection.',
                  style: AppText.label.copyWith(color: t.inkMuted, fontSize: 11)),
              const SizedBox(height: Sp.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int d = 1; d <= 7; d++)
                    GestureDetector(
                      onTap: () => _toggleDay(d),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _days.contains(d) ? t.ink : t.surfaceAlt,
                          borderRadius: BorderRadius.circular(R.s),
                          border: Border.all(color: t.divider),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d - 1],
                          style: AppText.bodyStrong
                              .copyWith(color: _days.contains(d) ? t.bg : t.ink),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Sp.lg),
              Row(
                children: [
                  Expanded(
                    child: _TimeBox(
                      label: 'Start',
                      value: _start,
                      onPick: (v) {
                        setState(() {
                          _start = v;
                          if (_toMin(_end) <= _toMin(_start)) {
                            final m = (_toMin(_start) + 60).clamp(0, 23 * 60 + 59);
                            _end = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: _TimeBox(
                      label: 'End',
                      value: _end,
                      onPick: (v) => setState(() => _end = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(widget.initial == null ? 'Add block' : 'Save block'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onPick;
  const _TimeBox({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
        const SizedBox(height: Sp.s),
        InkWell(
          borderRadius: BorderRadius.circular(R.s),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: value);
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: t.divider),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.clock, color: t.ink, size: IconSize.m),
                const SizedBox(width: Sp.s),
                Text(_fmt(value),
                    style: AppText.mono.copyWith(
                      color: t.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Custom expiry-date picker. Shows the next 8 weeks (Mon..Sun rows). Each
/// future date is tappable; each cell carries an "N" badge if the draft
/// has N blocks scheduled on that weekday so users can see the schedule's
/// real coverage before committing.
class _ExpiryCalendarSheet extends StatefulWidget {
  final DateTime initial;
  final Map<int, int> blocksByDow;
  const _ExpiryCalendarSheet({
    required this.initial,
    required this.blocksByDow,
  });

  @override
  State<_ExpiryCalendarSheet> createState() => _ExpiryCalendarSheetState();
}

class _ExpiryCalendarSheetState extends State<_ExpiryCalendarSheet> {
  late DateTime _selected;
  static const _weeksAhead = 8;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  DateTime _startMonday() {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return t.subtract(Duration(days: t.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final start = _startMonday();
    final totalBlocks = widget.blocksByDow.values.fold<int>(0, (a, b) => a + b);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.m, Sp.md, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(R.pill),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            Row(
              children: [
                Expanded(
                  child: Text('Pick expiry',
                      style: AppText.headline.copyWith(color: t.ink)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Sp.s),
            Text(
              totalBlocks == 0
                  ? 'No blocks yet. Add some after picking a date.'
                  : '$totalBlocks block${totalBlocks == 1 ? '' : 's'} per week. Numbers below show the block count for that weekday.',
              style: AppText.label.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: Sp.md),
            // Weekday header row.
            Row(
              children: [
                for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: AppText.label
                            .copyWith(color: t.inkMuted, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            for (int week = 0; week < _weeksAhead; week++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (int dow = 1; dow <= 7; dow++) ...[
                      Expanded(
                        child: _CalendarCell(
                          date: start.add(Duration(days: week * 7 + dow - 1)),
                          today: todayDate,
                          selected: _selected,
                          blockCount: widget.blocksByDow[dow] ?? 0,
                          // Only show coverage badges within the schedule's
                          // active window (today through the picked expiry).
                          // Beyond that, the schedule has lapsed so showing
                          // counts would mislead.
                          inActiveRange:
                              !start.add(Duration(days: week * 7 + dow - 1))
                                      .isBefore(todayDate) &&
                                  !start.add(Duration(days: week * 7 + dow - 1))
                                      .isAfter(_selected),
                          onTap: (d) => setState(() => _selected = d),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: Sp.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isBefore(todayDate)
                    ? null
                    : () => Navigator.of(context).pop(_selected),
                child: const Text('Set expiry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final DateTime selected;
  final int blockCount;

  /// True when this date is inside the active schedule window: at or after
  /// today and at or before the picked expiry. Outside that window the
  /// schedule does not run, so the block-count badge is hidden and the
  /// cell renders as plain to avoid implying coverage that isn't there.
  final bool inActiveRange;
  final ValueChanged<DateTime> onTap;
  const _CalendarCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.blockCount,
    required this.inActiveRange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isPast = date.isBefore(today);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == selected.year &&
        date.month == selected.month &&
        date.day == selected.day;
    final fg = isPast
        ? t.inkMuted.withValues(alpha: 0.4)
        : (isSelected ? t.bg : t.ink);
    final bg = isSelected
        ? t.ink
        : (isToday
            ? t.surfaceAlt
            : (inActiveRange
                ? t.accent.withValues(alpha: 0.08)
                : Colors.transparent));
    return InkWell(
      onTap: isPast ? null : () => onTap(date),
      borderRadius: BorderRadius.circular(R.s),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(R.s),
            border: Border.all(
              color: isSelected
                  ? t.ink
                  : (inActiveRange ? t.accent.withValues(alpha: 0.45) : t.divider),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  date.day.toString(),
                  style: AppText.bodyStrong.copyWith(color: fg, fontSize: 12),
                ),
              ),
              if (blockCount > 0 && !isPast && inActiveRange)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? t.bg : t.accent,
                      borderRadius: BorderRadius.circular(R.xs),
                    ),
                    child: Text(
                      blockCount.toString(),
                      style: AppText.label.copyWith(
                        color: isSelected ? t.ink : t.accentInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.s),
        decoration: BoxDecoration(
          color: selected ? t.ink : t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(
            color: selected ? t.ink : t.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.bodyStrong.copyWith(
            color: selected ? t.bg : t.ink,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

const List<String> _weekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String _weekdayName(int dow) => _weekdayLong[(dow - 1).clamp(0, 6)];

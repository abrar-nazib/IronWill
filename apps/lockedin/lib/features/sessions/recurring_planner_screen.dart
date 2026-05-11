import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../subjects/subject_edit_sheet.dart';

/// Bulk planner for recurring focus sessions. Lives behind Settings →
/// Focus sessions → "Plan recurring". The user picks:
///   * a subject (or none)
///   * which weekdays
///   * a start + end time
///   * a date range (today → "until")
/// We fan that out into one [FocusSession] per matching weekday inside
/// the range. Each draft is checked against existing sessions for
/// overlap before any disk writes happen, so the operation is all-or-
/// nothing: the user sees how many will be created AND how many would
/// conflict before they commit.
///
/// This intentionally has nothing in common with the quick-start sheet:
/// onboarding stays simple, advanced demands stay here.
class RecurringPlannerScreen extends StatefulWidget {
  const RecurringPlannerScreen({super.key});

  @override
  State<RecurringPlannerScreen> createState() => _RecurringPlannerScreenState();
}

enum _DayMode { weekdays, everyday, weekends, custom }

class _RecurringPlannerScreenState extends State<RecurringPlannerScreen> {
  String? _subjectId;
  _DayMode _mode = _DayMode.weekdays;
  Set<int> _days = const {1, 2, 3, 4, 5};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  late DateTime _until;
  bool _initialised = false;
  bool _saving = false;

  /// Per-draft state: when we run the preview, every fan-out date that
  /// already collides with another session is flagged so the user can
  /// see exactly which ones would be skipped. Recomputed every state
  /// change so the count + conflict list stay live.
  List<_DraftHit> _preview = const [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // Default to a single week (today + 6 days). Most users want to try
    // one week first and extend; opening on a month was too aggressive.
    _until = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 6));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final svc = AppServices.of(context);
    final subjects = svc.subjects.all.value;
    if (subjects.isNotEmpty) {
      final sorted = [...subjects]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _subjectId = sorted.first.id;
    }
    _rebuildPreview();
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  void _setMode(_DayMode m) {
    setState(() {
      _mode = m;
      switch (m) {
        case _DayMode.weekdays:
          _days = {1, 2, 3, 4, 5};
          break;
        case _DayMode.everyday:
          _days = {1, 2, 3, 4, 5, 6, 7};
          break;
        case _DayMode.weekends:
          _days = {6, 7};
          break;
        case _DayMode.custom:
          if (_days.isEmpty) _days = {1};
          break;
      }
      _rebuildPreview();
    });
  }

  void _toggleDay(int d) {
    setState(() {
      if (_days.contains(d)) {
        _days.remove(d);
      } else {
        _days.add(d);
      }
      _mode = _DayMode.custom;
      _rebuildPreview();
    });
  }

  Future<void> _pickStart() async {
    final picked =
        await showTimePicker(context: context, initialTime: _start);
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_toMin(_end) <= _toMin(_start)) {
        final m = (_toMin(_start) + 60).clamp(0, 23 * 60 + 59);
        _end = TimeOfDay(hour: m ~/ 60, minute: m % 60);
      }
      _rebuildPreview();
    });
  }

  Future<void> _pickEnd() async {
    final picked =
        await showTimePicker(context: context, initialTime: _end);
    if (picked == null) return;
    if (_toMin(picked) <= _toMin(_start)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pick a later end time'),
          content: const Text('End time must be after start time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _end = picked;
      _rebuildPreview();
    });
  }

  Future<void> _pickUntil() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _until.isBefore(today) ? today : _until,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _until = picked;
        _rebuildPreview();
      });
    }
  }

  void _bumpUntil(Duration d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      final candidate = _until.add(d);
      // Floor at today so the -1 week chip can't yank the planner into
      // the past and silently zero out the preview.
      _until = candidate.isBefore(today) ? today : candidate;
      _rebuildPreview();
    });
  }

  Future<void> _addSubject() async {
    final created = await showSubjectEditSheet(context);
    if (created != null && mounted) {
      setState(() => _subjectId = created.id);
    }
  }

  /// Build the candidate session list AND mark each as either OK or
  /// colliding (against any session already on disk OR earlier candidates
  /// inside this very plan). Triggers no I/O.
  void _rebuildPreview() {
    final svc = AppServices.of(context);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final until = DateTime(_until.year, _until.month, _until.day);
    if (until.isBefore(start) || _days.isEmpty) {
      _preview = const [];
      return;
    }
    if (_toMin(_end) <= _toMin(_start)) {
      _preview = const [];
      return;
    }
    final existing = [...svc.focusSessions.all.value];
    final hits = <_DraftHit>[];
    final accepted = <FocusSession>[];
    var day = start;
    while (!day.isAfter(until)) {
      if (_days.contains(day.weekday)) {
        final s =
            DateTime(day.year, day.month, day.day, _start.hour, _start.minute);
        final e =
            DateTime(day.year, day.month, day.day, _end.hour, _end.minute);
        FocusSession? conflict;
        for (final other in [...existing, ...accepted]) {
          if (s.isBefore(other.endAt) && other.startAt.isBefore(e)) {
            conflict = other;
            break;
          }
        }
        if (conflict == null) {
          accepted.add(FocusSession(
            id: 'tmp_${s.millisecondsSinceEpoch}',
            subjectId: _subjectId,
            startAt: s,
            endAt: e,
            createdAt: DateTime.now(),
          ));
        }
        hits.add(_DraftHit(
          start: s,
          end: e,
          conflictWith: conflict,
        ));
      }
      day = day.add(const Duration(days: 1));
    }
    _preview = hits;
  }

  Future<void> _commit() async {
    if (_preview.isEmpty) return;
    final svc = AppServices.of(context);
    setState(() => _saving = true);
    var created = 0;
    var skipped = 0;
    try {
      for (final hit in _preview) {
        if (hit.conflictWith != null) {
          skipped++;
          continue;
        }
        try {
          await svc.focusSessions.create(FocusSessionDraft(
            subjectId: _subjectId,
            startAt: hit.start,
            endAt: hit.end,
          ));
          created++;
        } on FocusSessionCollisionException {
          // Another draft in the same batch landed first. Treat it as a
          // skip rather than aborting the whole batch.
          skipped++;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          skipped == 0
              ? 'Created $created session${created == 1 ? '' : 's'}.'
              : 'Created $created, skipped $skipped colliding session${skipped == 1 ? '' : 's'}.',
        ),
        duration: const Duration(seconds: 4),
      ));
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accepted =
        _preview.where((h) => h.conflictWith == null).length;
    final conflicts =
        _preview.where((h) => h.conflictWith != null).length;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Plan recurring sessions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
        children: [
          AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Subject'),
                const SizedBox(height: Sp.s),
                ValueListenableBuilder<List<Subject>>(
                  valueListenable: AppServices.of(context).subjects.all,
                  builder: (_, subjects, ___) => _SubjectPicker(
                    subjects: subjects,
                    selectedId: _subjectId,
                    onChange: (id) => setState(() {
                      _subjectId = id;
                      _rebuildPreview();
                    }),
                    onAddNew: _addSubject,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.m),
          AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Days of the week'),
                const SizedBox(height: Sp.s),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'Weekdays',
                        selected: _mode == _DayMode.weekdays,
                        onTap: () => _setMode(_DayMode.weekdays),
                      ),
                    ),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: _ModeChip(
                        label: 'Every day',
                        selected: _mode == _DayMode.everyday,
                        onTap: () => _setMode(_DayMode.everyday),
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
                        selected: _mode == _DayMode.weekends,
                        onTap: () => _setMode(_DayMode.weekends),
                      ),
                    ),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: _ModeChip(
                        label: 'Custom',
                        selected: _mode == _DayMode.custom,
                        onTap: () => _setMode(_DayMode.custom),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int d = 1; d <= 7; d++)
                      GestureDetector(
                        onTap: () => _toggleDay(d),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                _days.contains(d) ? t.ink : t.surfaceAlt,
                            borderRadius: BorderRadius.circular(R.s),
                            border: Border.all(color: t.divider),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d - 1],
                            style: AppText.bodyStrong.copyWith(
                                color: _days.contains(d) ? t.bg : t.ink),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.m),
          AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Time of day'),
                const SizedBox(height: Sp.s),
                Row(
                  children: [
                    Expanded(
                      child: _TimeBox(
                        label: 'Start',
                        value: _start,
                        onTap: _pickStart,
                      ),
                    ),
                    const SizedBox(width: Sp.m),
                    Expanded(
                      child: _TimeBox(
                        label: 'End',
                        value: _end,
                        onTap: _pickEnd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xs),
                Text(
                  _formatDuration(Duration(
                      minutes: _toMin(_end) - _toMin(_start))),
                  style: AppText.label.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.m),
          AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Until'),
                const SizedBox(height: Sp.s),
                InkWell(
                  onTap: _pickUntil,
                  borderRadius: BorderRadius.circular(R.s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Sp.md, vertical: Sp.m),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(R.s),
                      border: Border.all(color: t.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            color: t.ink, size: IconSize.m),
                        const SizedBox(width: Sp.s),
                        Text(DateFormat('EEE, d MMM yyyy').format(_until),
                            style:
                                AppText.bodyStrong.copyWith(color: t.ink)),
                        const Spacer(),
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
                        onPressed: () =>
                            _bumpUntil(const Duration(days: -7)),
                        icon: const Icon(LucideIcons.minus, size: 14),
                        label: const Text('1 week'),
                      ),
                    ),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _bumpUntil(const Duration(days: 7)),
                        icon: const Icon(LucideIcons.plus, size: 14),
                        label: const Text('1 week'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.m),
          _PreviewSummary(
            accepted: accepted,
            conflicts: conflicts,
            preview: _preview,
          ),
          const SizedBox(height: Sp.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saving || accepted == 0) ? null : _commit,
              child: Text(accepted == 0
                  ? 'Nothing to create'
                  : 'Create $accepted session${accepted == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftHit {
  final DateTime start;
  final DateTime end;
  final FocusSession? conflictWith;
  const _DraftHit({
    required this.start,
    required this.end,
    required this.conflictWith,
  });
}

class _PreviewSummary extends StatelessWidget {
  final int accepted;
  final int conflicts;
  final List<_DraftHit> preview;
  const _PreviewSummary({
    required this.accepted,
    required this.conflicts,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Preview'),
          const SizedBox(height: Sp.s),
          if (preview.isEmpty)
            Text(
              'Adjust the days, times, and end date to see what will be created.',
              style: AppText.label.copyWith(color: t.inkMuted),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 6,
                  height: 22,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: Sp.s),
                Text(
                  '$accepted to create',
                  style: AppText.bodyStrong.copyWith(color: t.ink),
                ),
                const Spacer(),
                if (conflicts > 0)
                  Text(
                    '$conflicts conflict${conflicts == 1 ? '' : 's'}',
                    style: AppText.label.copyWith(color: t.accent),
                  ),
              ],
            ),
            const SizedBox(height: Sp.s),
            for (var i = 0; i < preview.length && i < 8; i++)
              _DraftRow(hit: preview[i]),
            if (preview.length > 8) ...[
              const SizedBox(height: Sp.xs),
              Text(
                '+ ${preview.length - 8} more',
                style: AppText.label.copyWith(color: t.inkMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  final _DraftHit hit;
  const _DraftRow({required this.hit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final conflict = hit.conflictWith != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: conflict ? t.accent : t.ink,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Text(
              DateFormat('EEE, d MMM').format(hit.start),
              style: AppText.label.copyWith(color: t.ink),
            ),
          ),
          Text(
            '${DateFormat('HH:mm').format(hit.start)} → ${DateFormat('HH:mm').format(hit.end)}',
            style: AppText.mono.copyWith(color: t.ink, fontSize: 12),
          ),
          if (conflict) ...[
            const SizedBox(width: Sp.s),
            Icon(LucideIcons.triangleAlert, color: t.accent, size: 13),
          ],
        ],
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

class _TimeBox extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;
  const _TimeBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.inkMuted)),
        const SizedBox(height: Sp.s),
        InkWell(
          onTap: onTap,
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
                Icon(LucideIcons.clock, color: t.ink, size: IconSize.m),
                const SizedBox(width: Sp.s),
                Text(
                  '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
                  style: AppText.mono.copyWith(
                    color: t.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectPicker extends StatelessWidget {
  final List<Subject> subjects;
  final String? selectedId;
  final ValueChanged<String?> onChange;
  final VoidCallback onAddNew;
  const _SubjectPicker({
    required this.subjects,
    required this.selectedId,
    required this.onChange,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        _Chip(
          label: 'No subject',
          selected: selectedId == null,
          onTap: () => onChange(null),
        ),
        for (final s in subjects)
          _Chip(
            label: s.name,
            selected: selectedId == s.id,
            onTap: () => onChange(s.id),
          ),
        InkWell(
          onTap: onAddNew,
          borderRadius: BorderRadius.circular(R.s),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: t.ink, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, color: t.ink, size: 14),
                const SizedBox(width: 4),
                Text('New subject',
                    style: AppText.bodyStrong
                        .copyWith(color: t.ink, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
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
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
        decoration: BoxDecoration(
          color: selected ? t.ink : t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: selected ? t.ink : t.divider),
        ),
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

String _formatDuration(Duration d) {
  if (d.isNegative || d == Duration.zero) return 'Pick times';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final per = h == 0 ? '${m}m' : (m == 0 ? '${h}h' : '${h}h ${m}m');
  return '$per per day';
}

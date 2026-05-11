import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../subjects/subject_edit_sheet.dart';

/// Quick-start sheet. Used wherever the user wants to launch a focus
/// session for the current day with minimal friction (onboarding, the
/// home Log tray, the Sessions screen FAB). No date picker: today is
/// implied. The user picks (a) a subject, (b) when it starts, and (c)
/// how long it runs from a small set of duration chips that visually
/// reflect their selection.
///
/// The richer date+time editor lives in `edit_session_sheet.dart` and is
/// only reached when the user taps an existing session row (where the
/// date matters because it might be tomorrow or last week).
Future<FocusSession?> showQuickStartSessionSheet(BuildContext context) {
  return showModalBottomSheet<FocusSession?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (_) => const _QuickStartSheet(),
  );
}

class _QuickStartSheet extends StatefulWidget {
  const _QuickStartSheet();

  @override
  State<_QuickStartSheet> createState() => _QuickStartSheetState();
}

class _QuickStartSheetState extends State<_QuickStartSheet> {
  late TimeOfDay _start;
  Duration _duration = const Duration(minutes: 30);
  String? _subjectId;
  bool _initialised = false;
  bool _saving = false;

  static const List<Duration> _presets = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default start = round up to the next 5-min boundary so the user
    // sees "now-ish" but never a moment in the past.
    final padding = (5 - now.minute % 5) % 5;
    final rounded = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(Duration(minutes: padding));
    _start = TimeOfDay(hour: rounded.hour, minute: rounded.minute);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    _subjectId = _pickDefaultSubject();
  }

  String? _pickDefaultSubject() {
    final svc = AppServices.of(context);
    final sessions = svc.focusSessions.all.value;
    if (sessions.isNotEmpty) {
      final sorted = [...sessions]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final id = sorted.first.subjectId;
      if (id != null) return id;
    }
    final subjects = svc.subjects.all.value;
    if (subjects.isEmpty) return null;
    final sorted = [...subjects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.id;
  }

  DateTime get _startAt {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _start.hour, _start.minute);
  }

  DateTime get _endAt => _startAt.add(_duration);

  /// Use a dialog (not a SnackBar) for blocking errors. SnackBars are
  /// attached to the root ScaffoldMessenger and survive both the sheet
  /// dismissal AND tab switches, which gave users a stuck banner they
  /// could only clear by restarting the app.
  Future<void> _showError(String msg, {String title = 'Cannot save'}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start,
      helpText: 'Pick start time',
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _addSubject() async {
    final created = await showSubjectEditSheet(context);
    if (created != null && mounted) {
      setState(() => _subjectId = created.id);
    }
  }

  Future<void> _save() async {
    if (!_endAt.isAfter(_startAt)) {
      _showError('Pick a non-zero duration.');
      return;
    }
    setState(() => _saving = true);
    final svc = AppServices.of(context);
    try {
      final created = await svc.focusSessions.create(FocusSessionDraft(
        subjectId: _subjectId,
        startAt: _startAt,
        endAt: _endAt,
      ));
      if (mounted) Navigator.of(context).pop(created);
    } on FocusSessionCollisionException catch (e) {
      _showError(
          "Overlaps another session ${_formatRange(e.existing.startAt, e.existing.endAt)}.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                    child: Text(
                      'Lock in for a session',
                      style: AppText.headline.copyWith(color: t.ink),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Sp.s),
              Text(
                "Today. Tap a subject, pick a start time, pick a duration. Done.",
                style: AppText.label.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: Sp.lg),
              Text('SUBJECT',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              ValueListenableBuilder<List<Subject>>(
                valueListenable: AppServices.of(context).subjects.all,
                builder: (_, subjects, _2) => _SubjectPicker(
                  subjects: subjects,
                  selectedId: _subjectId,
                  onChange: (id) => setState(() => _subjectId = id),
                  onAddNew: _addSubject,
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text('STARTS AT',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              InkWell(
                onTap: _pickStart,
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
                      Icon(LucideIcons.clock, color: t.ink, size: IconSize.m),
                      const SizedBox(width: Sp.s),
                      Text(_formatTime(_start),
                          style: AppText.mono.copyWith(
                            color: t.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      Text('today',
                          style: AppText.label.copyWith(color: t.inkMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text('DURATION',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              Row(
                children: [
                  for (var i = 0; i < _presets.length; i++) ...[
                    Expanded(
                      child: _DurationChip(
                        label: _formatDurationShort(_presets[i]),
                        selected: _duration == _presets[i],
                        onTap: () => setState(() => _duration = _presets[i]),
                      ),
                    ),
                    if (i < _presets.length - 1) const SizedBox(width: Sp.s),
                  ],
                ],
              ),
              const SizedBox(height: Sp.xs),
              Text('Ends at ${_formatTime(TimeOfDay.fromDateTime(_endAt))}',
                  style: AppText.label.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.x3l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Start session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DurationChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: Sp.s + 2),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(
            color: selected ? t.accent : t.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.bodyStrong.copyWith(
            color: selected ? t.accentInk : t.ink,
            fontSize: 14,
          ),
        ),
      ),
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
                Text(
                  'New subject',
                  style: AppText.bodyStrong
                      .copyWith(color: t.ink, fontSize: 13),
                ),
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

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h${m}m';
}

String _formatRange(DateTime start, DateTime end) =>
    '${_formatTime(TimeOfDay.fromDateTime(start))} → ${_formatTime(TimeOfDay.fromDateTime(end))}';

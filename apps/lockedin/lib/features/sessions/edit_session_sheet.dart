import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../subjects/subject_edit_sheet.dart';

/// Editor for an EXISTING focus session. The user reaches it by tapping
/// a row in the sessions list. Date matters here (the session might be
/// tomorrow or last week), so we expose full date+time pickers and a
/// delete affordance. Distinct from the quick-start sheet that lives at
/// onboarding/home/sessions-FAB and only deals with today.
Future<FocusSession?> showEditSessionSheet(
  BuildContext context, {
  required FocusSession existing,
}) {
  return showModalBottomSheet<FocusSession?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (_) => _EditSheet(existing: existing),
  );
}

class _EditSheet extends StatefulWidget {
  final FocusSession existing;
  const _EditSheet({required this.existing});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late DateTime _startAt;
  late DateTime _endAt;
  String? _subjectId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startAt = widget.existing.startAt;
    _endAt = widget.existing.endAt;
    _subjectId = widget.existing.subjectId;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required String label,
  }) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Pick $label date',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'Pick $label time',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(initial: _startAt, label: 'Start');
    if (picked == null) return;
    setState(() {
      _startAt = picked;
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 30));
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(initial: _endAt, label: 'End');
    if (picked == null) return;
    if (!picked.isAfter(_startAt)) {
      _showError('End must be after start.');
      return;
    }
    setState(() => _endAt = picked);
  }

  Future<void> _addSubject() async {
    final created = await showSubjectEditSheet(context);
    if (created != null && mounted) {
      setState(() => _subjectId = created.id);
    }
  }

  Future<void> _save() async {
    if (!_endAt.isAfter(_startAt)) {
      _showError('End must be after start.');
      return;
    }
    setState(() => _saving = true);
    final svc = AppServices.of(context);
    try {
      final updated = await svc.focusSessions.update(
        widget.existing.copyWith(
          subjectId: _subjectId,
          clearSubjectId: _subjectId == null,
          startAt: _startAt,
          endAt: _endAt,
        ),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on FocusSessionCollisionException catch (e) {
      _showError(
          "Overlaps another session ${DateFormat('EEE HH:mm').format(e.existing.startAt)}–${DateFormat('HH:mm').format(e.existing.endAt)}.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final svc = AppServices.of(context);
    await svc.focusSessions.delete(widget.existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = _endAt.difference(_startAt);
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
                      'Edit focus session',
                      style: AppText.headline.copyWith(color: t.ink),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Sp.lg),
              _Field(
                label: 'STARTS',
                icon: LucideIcons.play,
                value: _formatDateTime(_startAt),
                onTap: _pickStart,
              ),
              const SizedBox(height: Sp.s),
              _Field(
                label: 'ENDS',
                icon: LucideIcons.flag,
                value:
                    '${_formatDateTime(_endAt)}   ·   ${_formatDuration(duration)}',
                onTap: _pickEnd,
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
                builder: (_, subjects, ___) => _SubjectPicker(
                  subjects: subjects,
                  selectedId: _subjectId,
                  onChange: (id) => setState(() => _subjectId = id),
                  onAddNew: _addSubject,
                ),
              ),
              const SizedBox(height: Sp.x3l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save session'),
                ),
              ),
              const SizedBox(height: Sp.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _delete,
                  child: const Text('Delete session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  const _Field({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
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
            Icon(icon, color: t.ink, size: IconSize.m),
            const SizedBox(width: Sp.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: t.inkMuted)),
                  Text(value,
                      style: AppText.bodyStrong.copyWith(color: t.ink)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                color: t.inkMuted, size: IconSize.s),
          ],
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

String _formatDateTime(DateTime dt) {
  final today = DateTime.now();
  final isToday = dt.year == today.year &&
      dt.month == today.month &&
      dt.day == today.day;
  final isTomorrow = dt.year == today.year &&
      dt.month == today.month &&
      dt.day == today.day + 1;
  final time = DateFormat('HH:mm').format(dt);
  if (isToday) return 'Today $time';
  if (isTomorrow) return 'Tomorrow $time';
  return '${DateFormat('EEE, d MMM').format(dt)} $time';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

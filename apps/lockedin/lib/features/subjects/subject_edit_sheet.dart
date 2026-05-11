import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/local_db.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Bottom-sheet editor for a [Subject]. v6 subjects are just an umbrella
/// name plus a soft expiry hint; concrete time windows live on
/// FocusSession rows scheduled separately. So this sheet only edits
/// name + expiry + delete.
///
/// Pass `existing` to edit; omit to create.
Future<Subject?> showSubjectEditSheet(BuildContext context, {Subject? existing}) {
  return showModalBottomSheet<Subject?>(
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

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name ?? '');
    _expiresAt = s?.expiresAt ??
        DateTime.now().add(const Duration(days: LocalDb.defaultExpiryDays));
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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showError('Give the subject a name.');
      return;
    }
    FocusScope.of(context).unfocus();
    final svc = AppServices.of(context);
    Subject result;
    if (_isEditing) {
      result = await svc.subjects.update(widget.existing!.copyWith(
        name: _name.text.trim(),
        expiresAt: _expiresAt,
      ));
    } else {
      result = await svc.subjects.create(SubjectDraft(
        name: _name.text.trim(),
        expiresAt: _expiresAt,
      ));
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _pickExpiresAt() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt.isBefore(today) ? today : _expiresAt,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
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
    if (widget.existing != null) {
      await svc.subjects.delete(widget.existing!.id);
    }
    if (mounted) Navigator.of(context).pop();
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
              const SizedBox(height: Sp.s),
              Text(
                'Subjects are just labels. Plan concrete focus sessions under them from the home tab or Settings.',
                style: AppText.label.copyWith(color: t.inkMuted),
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
        Text('SOFT EXPIRY',
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

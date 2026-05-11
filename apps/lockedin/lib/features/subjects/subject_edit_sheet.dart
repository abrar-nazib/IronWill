import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/local_db.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Bottom-sheet editor for a [Subject]. Subjects are just labels. The
/// sheet is intentionally one field (plus delete when editing) so it
/// looks the same from onboarding, the inline "+ New subject" chip,
/// and the Settings → Subjects entry point. Soft expiry survives on
/// the model only for back-compat; we set it implicitly and never
/// expose it.
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

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Modal error dialog. Avoids the SnackBar-survives-tab-switch
  /// problem that bit the session sheets earlier.
  Future<void> _showError(String msg) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot save'),
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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showError('Give the subject a name.');
      return;
    }
    FocusScope.of(context).unfocus();
    final svc = AppServices.of(context);
    Subject result;
    if (_isEditing) {
      result = await svc.subjects.update(
        widget.existing!.copyWith(name: _name.text.trim()),
      );
    } else {
      // expiresAt is hidden chrome now: we still write a value so older
      // rows stay valid, but the user never sees or tweaks it.
      result = await svc.subjects.create(SubjectDraft(
        name: _name.text.trim(),
        expiresAt: DateTime.now()
            .add(const Duration(days: LocalDb.defaultExpiryDays)),
      ));
    }
    if (mounted) Navigator.of(context).pop(result);
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
                "Subjects are labels you tag focus sessions and logged blocks with.",
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
                onSubmitted: (_) => _save(),
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

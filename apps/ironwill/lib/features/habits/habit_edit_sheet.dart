import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The 8 most-common glyphs surfaced inline. Anything more lives behind the
/// "More" tile and the categorised picker.
const _quickGlyphs = <IconData>[
  LucideIcons.target,
  LucideIcons.dumbbell,
  LucideIcons.bookOpen,
  LucideIcons.brain,
  LucideIcons.droplet,
  LucideIcons.bed,
  LucideIcons.sunrise,
  LucideIcons.heart,
];

/// Categorised glyph library for the "More" picker. Keep groups themed so
/// users can scan to a section instead of skimming a flat 100-icon list.
const Map<String, List<IconData>> _glyphCategories = {
  'Body': [
    LucideIcons.dumbbell,
    LucideIcons.bike,
    LucideIcons.footprints,
    LucideIcons.activity,
    LucideIcons.heart,
    LucideIcons.heartPulse,
    LucideIcons.flame,
    LucideIcons.medal,
    LucideIcons.timer,
  ],
  'Mind': [
    LucideIcons.brain,
    LucideIcons.bookOpen,
    LucideIcons.notebookPen,
    LucideIcons.feather,
    LucideIcons.lightbulb,
    LucideIcons.graduationCap,
    LucideIcons.target,
    LucideIcons.compass,
    LucideIcons.glasses,
  ],
  'Wellness': [
    LucideIcons.bed,
    LucideIcons.moon,
    LucideIcons.sunrise,
    LucideIcons.sun,
    LucideIcons.droplet,
    LucideIcons.leaf,
    LucideIcons.apple,
    LucideIcons.coffee,
    LucideIcons.bath,
  ],
  'Discipline': [
    LucideIcons.shield,
    LucideIcons.shieldOff,
    LucideIcons.snowflake,
    LucideIcons.lock,
    LucideIcons.handCoins,
    LucideIcons.checkCheck,
    LucideIcons.flag,
    LucideIcons.alarmClock,
    LucideIcons.clock,
  ],
  'Craft': [
    LucideIcons.code,
    LucideIcons.terminal,
    LucideIcons.hammer,
    LucideIcons.palette,
    LucideIcons.music,
    LucideIcons.camera,
    LucideIcons.pencil,
    LucideIcons.briefcase,
    LucideIcons.guitar,
  ],
};

Future<void> showHabitEditSheet(BuildContext context, {Habit? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (ctx) => _HabitEditSheet(existing: existing),
  );
}

class _HabitEditSheet extends StatefulWidget {
  final Habit? existing;
  const _HabitEditSheet({this.existing});

  @override
  State<_HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends State<_HabitEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late HabitCadence _cadence;
  late List<int> _customDays;
  late IconData _glyph;
  late TimeOfDay _reminder;
  late bool _reminderOn;
  late List<HabitField> _fields;
  bool _saving = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _name = TextEditingController(text: h?.name ?? '');
    _description = TextEditingController(text: h?.description ?? '');
    _cadence = h?.cadence ?? HabitCadence.daily;
    // Custom days: editing keeps whatever the user had; new habits seed all 7
    // so flipping to "Custom days" doesn't start from an empty selection.
    _customDays = [...(h?.customDays ?? const [1, 2, 3, 4, 5, 6, 7])];
    _glyph = h?.glyph ?? LucideIcons.target;
    // Default 6:00 PM. A reminder typically lands when the user is winding
    // down their day, not at sunrise.
    _reminder = h?.reminder ?? const TimeOfDay(hour: 18, minute: 0);
    _reminderOn = h?.reminderOn ?? true;
    _fields = h == null ? [] : parseHabitFields(h.metadata);
    // Auto-expand the "Advanced" section if the habit already has fields,
    // so editors can see them at a glance.
    _showAdvanced = _fields.isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final svc = AppServices.of(context);
    final h = widget.existing;
    final metadata = habitMetadataFromFields(_fields);
    if (h == null) {
      await svc.habits.create(HabitDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        metadata: metadata,
        cadence: _cadence,
        customDays: _customDays,
        glyph: _glyph,
        reminder: _reminder,
        reminderOn: _reminderOn,
      ));
    } else {
      await svc.habits.update(h.copyWith(
        name: _name.text.trim(),
        description: _description.text.trim(),
        metadata: metadata,
        cadence: _cadence,
        customDays: _customDays,
        glyph: _glyph,
        reminder: _reminder,
        reminderOn: _reminderOn,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addField() async {
    final created = await showDialog<HabitField>(
      context: context,
      builder: (_) => const _FieldEditorDialog(),
    );
    if (!mounted || created == null) return;
    final clash = _fields.any(
        (f) => f.key.toLowerCase() == created.key.toLowerCase());
    if (clash) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${created.key}" already exists.'),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    setState(() => _fields.add(created));
  }

  Future<void> _editField(int index) async {
    final updated = await showDialog<HabitField>(
      context: context,
      builder: (_) => _FieldEditorDialog(initial: _fields[index]),
    );
    if (updated != null) setState(() => _fields[index] = updated);
  }

  Future<void> _openGlyphLibrary() async {
    final picked = await showModalBottomSheet<IconData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      builder: (_) => _GlyphLibrarySheet(current: _glyph),
    );
    if (picked != null) setState(() => _glyph = picked);
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
                      widget.existing == null ? 'New habit' : 'Edit habit',
                      style: AppText.headline.copyWith(color: t.ink),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Sp.md),

              Text('HABIT NAME', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              TextField(
                controller: _name,
                autofocus: widget.existing == null,
                style: AppText.body.copyWith(color: t.ink, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'No social media before noon',
                ),
              ),
              const SizedBox(height: Sp.lg),

              Text('RULES OR NOTES', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              TextField(
                controller: _description,
                maxLines: 4,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                style: AppText.body.copyWith(color: t.ink, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Counts as Done if I do not unlock Instagram, Twitter, or YouTube before 12:00. Reading the news is fine.',
                ),
              ),
              const SizedBox(height: Sp.lg),

              Text('GLYPH', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              _GlyphRow(
                current: _glyph,
                onPick: (g) => setState(() => _glyph = g),
                onMore: _openGlyphLibrary,
              ),
              const SizedBox(height: Sp.lg),

              Text('CADENCE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              _CadenceGrid(
                value: _cadence,
                onChange: (c) => setState(() => _cadence = c),
              ),
              if (_cadence == HabitCadence.custom) ...[
                const SizedBox(height: Sp.s),
                _DayPicker(
                  selectedDays: _customDays,
                  onChange: (d) => setState(() => _customDays = d),
                ),
              ],
              const SizedBox(height: Sp.lg),

              Text('REMINDER', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(R.s),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _reminder);
                        if (picked != null) setState(() => _reminder = picked);
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
                            Text(
                              '${_reminder.hour.toString().padLeft(2, '0')}:${_reminder.minute.toString().padLeft(2, '0')}',
                              style: AppText.bodyStrong.copyWith(color: t.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Switch(
                    value: _reminderOn,
                    onChanged: (v) => setState(() => _reminderOn = v),
                    activeThumbColor: t.accent,
                  ),
                ],
              ),
              const SizedBox(height: Sp.lg),

              _AdvancedToggle(
                expanded: _showAdvanced,
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                fieldCount: _fields.length,
              ),
              if (_showAdvanced) ...[
                const SizedBox(height: Sp.s),
                _TrackingFieldsSection(
                  fields: _fields,
                  onAdd: _addField,
                  onEdit: _editField,
                  onDelete: (i) => setState(() => _fields.removeAt(i)),
                ),
              ],
              const SizedBox(height: Sp.x3l),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(widget.existing == null ? 'Create habit' : 'Save changes'),
                ),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: Sp.s),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await AppServices.of(context).habits.archive(widget.existing!.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Archive habit'),
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

/// Inline glyph strip showing the 8 most common picks plus a "More" tile that
/// opens the categorised library. If the user's current glyph is outside the
/// quick list, it gets injected at the front so it is always visible.
class _GlyphRow extends StatelessWidget {
  final IconData current;
  final ValueChanged<IconData> onPick;
  final VoidCallback onMore;
  const _GlyphRow({
    required this.current,
    required this.onPick,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final inline = <IconData>[..._quickGlyphs];
    if (!inline.contains(current)) {
      inline.insert(0, current);
      if (inline.length > _quickGlyphs.length) inline.removeLast();
    }
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        for (final g in inline)
          _GlyphTile(
            glyph: g,
            selected: g == current,
            onTap: () => onPick(g),
          ),
        _GlyphMoreTile(onTap: onMore, accent: t.ink),
      ],
    );
  }
}

class _GlyphTile extends StatelessWidget {
  final IconData glyph;
  final bool selected;
  final VoidCallback onTap;
  const _GlyphTile({
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(R.s),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? t.ink : t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        alignment: Alignment.center,
        child: Icon(glyph, color: selected ? t.bg : t.ink, size: IconSize.m),
      ),
    );
  }
}

class _GlyphMoreTile extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  const _GlyphMoreTile({required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(R.s),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: accent, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Icon(LucideIcons.ellipsis, color: accent, size: IconSize.m),
      ),
    );
  }
}

/// Floating modal sheet that lists every glyph grouped by category. Returns
/// the picked glyph, or null on dismiss.
class _GlyphLibrarySheet extends StatelessWidget {
  final IconData current;
  const _GlyphLibrarySheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
                  child: Text('Pick a glyph',
                      style: AppText.headline.copyWith(color: t.ink)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Sp.s),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _glyphCategories.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.m, bottom: Sp.s),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: t.inkMuted),
                        ),
                      ),
                      Wrap(
                        spacing: Sp.s,
                        runSpacing: Sp.s,
                        children: [
                          for (final g in entry.value)
                            _GlyphTile(
                              glyph: g,
                              selected: g == current,
                              onTap: () => Navigator.of(context).pop(g),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2x2 cadence grid. Replaces the vertical RadioListTile stack so the section
/// fits in less vertical space and the four options can be scanned at a
/// glance.
class _CadenceGrid extends StatelessWidget {
  final HabitCadence value;
  final ValueChanged<HabitCadence> onChange;
  const _CadenceGrid({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _cell(context, HabitCadence.daily)),
            const SizedBox(width: Sp.s),
            Expanded(child: _cell(context, HabitCadence.weekdays)),
          ],
        ),
        const SizedBox(height: Sp.s),
        Row(
          children: [
            Expanded(child: _cell(context, HabitCadence.weekends)),
            const SizedBox(width: Sp.s),
            Expanded(child: _cell(context, HabitCadence.custom)),
          ],
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, HabitCadence c) {
    final t = context.tokens;
    final selected = value == c;
    return InkWell(
      borderRadius: BorderRadius.circular(R.s),
      onTap: () => onChange(c),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
        decoration: BoxDecoration(
          color: selected ? t.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(
            color: selected ? t.ink : t.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? t.ink : t.divider,
                  width: 2,
                ),
                color: selected ? t.ink : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: t.bg,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: Sp.s),
            Expanded(
              child: Text(
                c.label,
                style: AppText.bodyStrong.copyWith(color: t.ink, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap-to-expand row that gates the tracking-fields editor as an "Advanced"
/// option. Most users skip it; power users (e.g. counting reps per day) can
/// reveal it without cluttering the main editor.
class _AdvancedToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  final int fieldCount;
  const _AdvancedToggle({
    required this.expanded,
    required this.onTap,
    required this.fieldCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final summary = fieldCount == 0
        ? 'Track per-day numbers, lists, or yes/no'
        : '$fieldCount field${fieldCount == 1 ? '' : 's'} configured';
    return InkWell(
      borderRadius: BorderRadius.circular(R.s),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.slidersHorizontal, color: t.ink, size: IconSize.m),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Advanced: tracking fields',
                      style: AppText.bodyStrong.copyWith(color: t.ink)),
                  Text(summary,
                      style: AppText.label.copyWith(color: t.inkMuted)),
                ],
              ),
            ),
            Icon(
              expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              color: t.inkMuted,
              size: IconSize.m,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingFieldsSection extends StatelessWidget {
  final List<HabitField> fields;
  final Future<void> Function() onAdd;
  final Future<void> Function(int) onEdit;
  final void Function(int) onDelete;
  const _TrackingFieldsSection({
    required this.fields,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Optional. Add fields like "PU" (pushup reps as a number) so you can record a value per day and compare over time.',
                style: AppText.label.copyWith(color: t.inkMuted, fontSize: 12),
              ),
            ),
            const SizedBox(width: Sp.s),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add field'),
            ),
          ],
        ),
        const SizedBox(height: Sp.s),
        if (fields.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: t.divider),
            ),
            child: Text(
              'No tracking fields. Tap "Add field" to define one.',
              style: AppText.label.copyWith(color: t.inkMuted),
            ),
          )
        else
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _FieldRow(
                field: fields[i],
                onTap: () => onEdit(i),
                onDelete: () => onDelete(i),
              ),
            ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  final HabitField field;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _FieldRow({
    required this.field,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(R.xs),
                border: Border.all(color: t.divider),
              ),
              child: Text(field.key,
                  style: AppText.mono
                      .copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(field.type.label,
                  style: AppText.label.copyWith(color: t.inkMuted)),
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

/// Modal that creates or edits a single [HabitField]. Returns the new field
/// on save, null on cancel. Uses inline validation so the dialog never has to
/// show a snackbar from inside its own context.
class _FieldEditorDialog extends StatefulWidget {
  final HabitField? initial;
  const _FieldEditorDialog({this.initial});

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late TextEditingController _key;
  late HabitFieldType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.initial?.key ?? '');
    // Default to "number" — list types are specialised; most users want a
    // single value per day (reps, pages, minutes).
    _type = widget.initial?.type ?? HabitFieldType.number;
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _save() {
    final key = _key.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Field key cannot be empty.');
      return;
    }
    Navigator.of(context).pop(HabitField(key: key, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      backgroundColor: t.surface,
      title: Text(widget.initial == null ? 'New field' : 'Edit field',
          style: AppText.headline.copyWith(color: t.ink, fontSize: 22)),
      contentPadding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KEY (short)',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: t.inkMuted)),
            const SizedBox(height: Sp.s),
            TextField(
              controller: _key,
              autofocus: widget.initial == null,
              style: AppText.body.copyWith(color: t.ink, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'PU',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: Sp.lg),
            Text('TYPE',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: t.inkMuted)),
            const SizedBox(height: Sp.s),
            for (final tp in HabitFieldType.values)
              _TypeRow(
                type: tp,
                selected: _type == tp,
                onTap: () => setState(() => _type = tp),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(widget.initial == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _TypeRow extends StatelessWidget {
  final HabitFieldType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(R.s),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
          decoration: BoxDecoration(
            color: selected ? t.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(R.s),
            border: Border.all(
              color: selected ? t.ink : t.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.ink : t.divider,
                    width: 2,
                  ),
                  color: selected ? t.ink : Colors.transparent,
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: t.bg,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label,
                        style: AppText.bodyStrong.copyWith(color: t.ink)),
                    Text(type.hint,
                        style: AppText.label.copyWith(color: t.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChange;
  const _DayPicker({required this.selectedDays, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int d = 1; d <= 7; d++)
          GestureDetector(
            onTap: () {
              final next = [...selectedDays];
              if (next.contains(d)) {
                next.remove(d);
              } else {
                next.add(d);
              }
              next.sort();
              onChange(next);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedDays.contains(d) ? t.ink : t.surfaceAlt,
                borderRadius: BorderRadius.circular(R.s),
                border: Border.all(color: t.divider),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[d - 1],
                style: AppText.bodyStrong.copyWith(
                  color: selectedDays.contains(d) ? t.bg : t.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

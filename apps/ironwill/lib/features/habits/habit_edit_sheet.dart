import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

const _glyphChoices = <IconData>[
  LucideIcons.shieldOff,
  LucideIcons.snowflake,
  LucideIcons.bookOpen,
  LucideIcons.dumbbell,
  LucideIcons.moon,
  LucideIcons.sunrise,
  LucideIcons.brain,
  LucideIcons.coffee,
  LucideIcons.droplet,
  LucideIcons.heart,
  LucideIcons.footprints,
  LucideIcons.notebookPen,
  LucideIcons.target,
  LucideIcons.clock,
  LucideIcons.bike,
  LucideIcons.leaf,
];

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _name = TextEditingController(text: h?.name ?? '');
    _description = TextEditingController(text: h?.description ?? '');
    _cadence = h?.cadence ?? HabitCadence.daily;
    _customDays = [...(h?.customDays ?? const [1, 2, 3, 4, 5])];
    _glyph = h?.glyph ?? LucideIcons.target;
    _reminder = h?.reminder ?? const TimeOfDay(hour: 7, minute: 0);
    _reminderOn = h?.reminderOn ?? true;
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
    if (h == null) {
      await svc.habits.create(HabitDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
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
        cadence: _cadence,
        customDays: _customDays,
        glyph: _glyph,
        reminder: _reminder,
        reminderOn: _reminderOn,
      ));
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
              Wrap(
                spacing: Sp.s,
                runSpacing: Sp.s,
                children: [
                  for (final g in _glyphChoices)
                    InkWell(
                      borderRadius: BorderRadius.circular(R.s),
                      onTap: () => setState(() => _glyph = g),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: g == _glyph ? t.ink : t.surfaceAlt,
                          borderRadius: BorderRadius.circular(R.s),
                          border: Border.all(color: t.divider),
                        ),
                        alignment: Alignment.center,
                        child: Icon(g, color: g == _glyph ? t.bg : t.ink, size: IconSize.m),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Sp.lg),

              Text('CADENCE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              Column(
                children: [
                  for (final c in HabitCadence.values)
                    _CadenceRow(
                      cadence: c,
                      selected: _cadence == c,
                      onTap: () => setState(() => _cadence = c),
                    ),
                ],
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

class _CadenceRow extends StatelessWidget {
  final HabitCadence cadence;
  final bool selected;
  final VoidCallback onTap;
  const _CadenceRow({required this.cadence, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(R.s),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
          decoration: BoxDecoration(
            color: selected ? t.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(R.s),
            border: Border.all(color: selected ? t.ink : t.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? t.ink : t.divider, width: 2),
                  color: selected ? t.ink : Colors.transparent,
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: Sp.m),
              Text(cadence.label, style: AppText.bodyStrong.copyWith(color: t.ink)),
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

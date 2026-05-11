import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../models/utilization.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

Future<void> showHabitLogSheet(
  BuildContext context, {
  required Habit habit,
  DateTime? day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (ctx) => _HabitLogSheet(habit: habit, day: day),
  );
}

class _HabitLogSheet extends StatefulWidget {
  final Habit habit;
  final DateTime? day;
  const _HabitLogSheet({required this.habit, this.day});

  @override
  State<_HabitLogSheet> createState() => _HabitLogSheetState();
}

class _HabitLogSheetState extends State<_HabitLogSheet> {
  Utilization? _picked;
  final _note = TextEditingController();
  bool _loading = true;
  bool _hydrated = false;

  /// One controller per field: text/number values use the same controller;
  /// list types parse a comma-separated string ("15, 12, 10" → [15,12,10]).
  /// Booleans use [_boolValues] instead.
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, bool> _boolValues = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    _hydrate();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _hydrate() async {
    final svc = AppServices.of(context);
    final day = widget.day ?? DateTime.now();
    final existing = await svc.habits.getLog(widget.habit.id, day);
    if (!mounted) return;
    final fields = parseHabitFields(widget.habit.metadata);
    final logMeta = existing?.metadata ?? const {};
    for (final f in fields) {
      switch (f.type) {
        case HabitFieldType.boolean:
          _boolValues[f.key] = (logMeta[f.key] as bool?) ?? false;
          break;
        case HabitFieldType.boolList:
          final raw = logMeta[f.key];
          final list = (raw is List)
              ? raw.map((e) => (e == true) ? 'yes' : 'no').toList()
              : <String>[];
          _fieldControllers[f.key] =
              TextEditingController(text: list.join(', '));
          break;
        case HabitFieldType.intList:
          final raw = logMeta[f.key];
          final list = (raw is List)
              ? raw.map((e) => e.toString()).toList()
              : <String>[];
          _fieldControllers[f.key] =
              TextEditingController(text: list.join(', '));
          break;
        case HabitFieldType.number:
          _fieldControllers[f.key] =
              TextEditingController(text: (logMeta[f.key]?.toString()) ?? '');
          break;
        case HabitFieldType.text:
          _fieldControllers[f.key] =
              TextEditingController(text: (logMeta[f.key]?.toString()) ?? '');
          break;
      }
    }
    setState(() {
      _picked = existing?.utilization;
      _note.text = existing?.note ?? '';
      _loading = false;
    });
  }

  Map<String, Object?> _collectMetadata(List<HabitField> fields) {
    final out = <String, Object?>{};
    for (final f in fields) {
      switch (f.type) {
        case HabitFieldType.boolean:
          out[f.key] = _boolValues[f.key] ?? false;
          break;
        case HabitFieldType.boolList:
          final raw = (_fieldControllers[f.key]?.text ?? '').trim();
          if (raw.isEmpty) continue;
          out[f.key] = raw
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .map((s) => s == 'y' || s == 'yes' || s == 'true' || s == '1')
              .toList();
          break;
        case HabitFieldType.intList:
          final raw = (_fieldControllers[f.key]?.text ?? '').trim();
          if (raw.isEmpty) continue;
          final parsed = raw
              .split(',')
              .map((s) => int.tryParse(s.trim()))
              .where((v) => v != null)
              .cast<int>()
              .toList();
          out[f.key] = parsed;
          break;
        case HabitFieldType.number:
          final raw = (_fieldControllers[f.key]?.text ?? '').trim();
          if (raw.isEmpty) continue;
          final n = int.tryParse(raw);
          if (n != null) out[f.key] = n;
          break;
        case HabitFieldType.text:
          final raw = (_fieldControllers[f.key]?.text ?? '').trim();
          if (raw.isNotEmpty) out[f.key] = raw;
          break;
      }
    }
    return out;
  }

  String _dateLabel() {
    final d = widget.day;
    if (d == null) return 'Today';
    return '${d.day} ${_monthShort(d.month)} ${d.year}';
  }

  static String _monthShort(int m) =>
      const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  Future<void> _save() async {
    final picked = _picked;
    if (picked == null) return;
    final svc = AppServices.of(context);
    final day = widget.day;
    final note = _note.text.trim();
    final fields = parseHabitFields(widget.habit.metadata);
    final metadata = _collectMetadata(fields);
    if (day == null) {
      await svc.habits.logToday(widget.habit.id, picked,
          note: note, metadata: metadata);
    } else {
      await svc.habits.logDay(widget.habit.id, day, picked,
          note: note, metadata: metadata);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    final svc = AppServices.of(context);
    final day = widget.day;
    if (day == null) {
      await svc.habits.logToday(widget.habit.id, Utilization.none);
    } else {
      await svc.habits.logDay(widget.habit.id, day, Utilization.none);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final options = const [
      Utilization.full,
      Utilization.good,
      Utilization.mid,
      Utilization.low,
      Utilization.wasted,
    ];
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(R.s),
                      border: Border.all(color: t.divider),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.habit.glyph, color: t.ink, size: IconSize.m),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Log ${_dateLabel().toLowerCase()}',
                            style: AppText.label.copyWith(color: t.inkMuted)),
                        Text(widget.habit.name, style: AppText.title.copyWith(color: t.ink)),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.habit.description.isNotEmpty) ...[
                const SizedBox(height: Sp.m),
                Container(
                  padding: const EdgeInsets.all(Sp.m),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(R.s),
                    border: Border.all(color: t.divider),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.scroll, color: t.inkMuted, size: IconSize.s),
                      const SizedBox(width: Sp.s),
                      Expanded(
                        child: Text(
                          widget.habit.description,
                          style: AppText.label.copyWith(color: t.inkMuted, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Sp.lg),
              Text('HOW DID IT GO?',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Sp.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Column(
                  children: [
                    for (final u in options)
                      _PickRow(
                        util: u,
                        selected: _picked == u,
                        onTap: () => setState(() => _picked = u),
                      ),
                  ],
                ),
              if (!_loading) ...[
                Builder(builder: (_) {
                  final fields = parseHabitFields(widget.habit.metadata);
                  if (fields.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Sp.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TODAY\'S NUMBERS',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: t.inkMuted)),
                        const SizedBox(height: Sp.s),
                        for (final f in fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.s),
                            child: _FieldInput(
                              field: f,
                              controller: _fieldControllers[f.key],
                              boolValue: _boolValues[f.key] ?? false,
                              onBoolChanged: (v) =>
                                  setState(() => _boolValues[f.key] = v),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: Sp.lg),
              Text('NOTE (OPTIONAL)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                style: AppText.body.copyWith(color: t.ink, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'How was today? Anything to remember.',
                ),
              ),
              const SizedBox(height: Sp.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _picked == null ? null : _save,
                  child: const Text('Save log'),
                ),
              ),
              const SizedBox(height: Sp.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.eraser),
                  label: const Text('Clear log for this day'),
                  onPressed: _clear,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Type-aware editor for one habit field on a single day.
class _FieldInput extends StatelessWidget {
  final HabitField field;
  final TextEditingController? controller;
  final bool boolValue;
  final ValueChanged<bool> onBoolChanged;
  const _FieldInput({
    required this.field,
    required this.controller,
    required this.boolValue,
    required this.onBoolChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final keyChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(R.xs),
        border: Border.all(color: t.divider),
      ),
      child: Text(field.key,
          style: AppText.mono.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w700,
          )),
    );
    if (field.type == HabitFieldType.boolean) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        child: Row(
          children: [
            keyChip,
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(field.type.label,
                  style: AppText.label.copyWith(color: t.inkMuted)),
            ),
            Switch.adaptive(
              value: boolValue,
              onChanged: onBoolChanged,
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        children: [
          keyChip,
          const SizedBox(width: Sp.m),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: field.type == HabitFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              style: AppText.body.copyWith(color: t.ink, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: field.type.hint,
                hintStyle: AppText.label.copyWith(color: t.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final Utilization util;
  final bool selected;
  final VoidCallback onTap;
  const _PickRow({required this.util, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        margin: const EdgeInsets.only(bottom: Sp.s),
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.m),
        decoration: BoxDecoration(
          color: selected ? t.surfaceAlt : t.surface,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: selected ? t.ink : t.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: util.color(t),
                borderRadius: BorderRadius.circular(R.xs),
              ),
            ),
            const SizedBox(width: Sp.m),
            Expanded(child: Text(util.habitLabel, style: AppText.bodyStrong.copyWith(color: t.ink))),
            if (util.percent != null)
              Text('${util.percent}%', style: AppText.mono.copyWith(color: t.inkMuted)),
            const SizedBox(width: Sp.s),
            if (selected) Icon(LucideIcons.check, color: t.ink, size: IconSize.m),
          ],
        ),
      ),
    );
  }
}

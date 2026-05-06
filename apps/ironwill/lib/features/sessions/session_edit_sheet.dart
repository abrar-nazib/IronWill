import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

Future<void> showSessionEditSheet(BuildContext context, {FocusSession? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (ctx) => _SessionEditSheet(existing: existing),
  );
}

class _SessionEditSheet extends StatefulWidget {
  final FocusSession? existing;
  const _SessionEditSheet({this.existing});

  @override
  State<_SessionEditSheet> createState() => _SessionEditSheetState();
}

class _SessionEditSheetState extends State<_SessionEditSheet> {
  late final TextEditingController _name;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late List<int> _days;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name ?? '');
    _start = s?.start ?? const TimeOfDay(hour: 6, minute: 0);
    _end = s?.end ?? const TimeOfDay(hour: 9, minute: 0);
    _days = [...(s?.daysOfWeek ?? const [1, 2, 3, 4, 5])];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final svc = AppServices.of(context);
    if (widget.existing == null) {
      await svc.sessions.create(FocusSessionDraft(
        name: _name.text.trim(),
        start: _start,
        end: _end,
        daysOfWeek: _days,
      ));
    } else {
      await svc.sessions.update(widget.existing!.copyWith(
        name: _name.text.trim(),
        start: _start,
        end: _end,
        daysOfWeek: _days,
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
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(R.pill)),
                ),
              ),
              const SizedBox(height: Sp.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'New focus session' : 'Edit focus session',
                      style: AppText.headline.copyWith(color: t.ink),
                    ),
                  ),
                  IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: Sp.md),
              Text('SESSION NAME',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              TextField(
                controller: _name,
                autofocus: widget.existing == null,
                style: AppText.body.copyWith(color: t.ink, fontSize: 16),
                decoration: const InputDecoration(hintText: 'Deep work block'),
              ),
              const SizedBox(height: Sp.lg),
              Row(
                children: [
                  Expanded(child: _TimeBox(label: 'Start', value: _start, onPick: (v) => setState(() => _start = v))),
                  const SizedBox(width: Sp.m),
                  Expanded(child: _TimeBox(label: 'End', value: _end, onPick: (v) => setState(() => _end = v))),
                ],
              ),
              const SizedBox(height: Sp.lg),
              Text('REPEATS ON',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: Sp.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int d = 1; d <= 7; d++)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_days.contains(d)) {
                            _days.remove(d);
                          } else {
                            _days.add(d);
                            _days.sort();
                          }
                        });
                      },
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
                          style: AppText.bodyStrong.copyWith(color: _days.contains(d) ? t.bg : t.ink),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Sp.x3l),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(widget.existing == null ? 'Create session' : 'Save changes'),
                ),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: Sp.s),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await AppServices.of(context).sessions.delete(widget.existing!.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Delete session'),
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
                Text(
                  '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
                  style: AppText.mono.copyWith(color: t.ink, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

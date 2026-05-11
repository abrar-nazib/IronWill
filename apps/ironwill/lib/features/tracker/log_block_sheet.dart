import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../models/utilization.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Render a "HH:MM to HH:MM" label spanning the [blockSizeMinutes] window
/// that starts at quarter [q]. The 15 minute granularity of `q` survives:
/// a 30-min block at quarter 4 reads "01:00 to 01:30".
String quarterLabel(int q, {int blockSizeMinutes = 15}) {
  final stride = blockSizeMinutes ~/ 15;
  final endIdx = q + stride;
  final h = (q ~/ 4).toString().padLeft(2, '0');
  final m = ((q % 4) * 15).toString().padLeft(2, '0');
  final endH = ((endIdx ~/ 4) % 24).toString().padLeft(2, '0');
  final endM = ((endIdx % 4) * 15).toString().padLeft(2, '0');
  return '$h:$m to $endH:$endM';
}

/// Result of [showLogBlockSheet]. Carries the chosen utilization and the
/// subject the user picked (or `null` for no subject). The caller writes
/// these to all sub-quarters of the block.
class LogBlockResult {
  final Utilization utilization;
  final String? subjectId;
  final bool clearSubjectId;
  const LogBlockResult({
    required this.utilization,
    required this.subjectId,
    required this.clearSubjectId,
  });
}

/// Render the "how focused were you?" sheet. [candidateSubjects] is the
/// list of subjects to offer in the picker; when [autoPickedSubjectId]
/// is non-null it pre-selects that subject (typically inferred from a
/// focus session overlapping this block). Pass [askWhichSession] = true
/// to highlight that multiple sessions overlap so the user picks
/// deliberately.
Future<LogBlockResult?> showLogBlockSheet(
  BuildContext context, {
  required Utilization current,
  required int quarterIndex,
  int blockSizeMinutes = 15,
  List<Subject> candidateSubjects = const [],
  String? currentSubjectId,
  String? autoPickedSubjectId,
  bool askWhichSession = false,
}) {
  return showModalBottomSheet<LogBlockResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).extension<AppTokens>()!.surface,
    builder: (ctx) => _LogSheet(
      current: current,
      quarterIndex: quarterIndex,
      blockSizeMinutes: blockSizeMinutes,
      candidateSubjects: candidateSubjects,
      initialSubjectId: autoPickedSubjectId ?? currentSubjectId,
      askWhichSession: askWhichSession,
    ),
  );
}

class _LogSheet extends StatefulWidget {
  final Utilization current;
  final int quarterIndex;
  final int blockSizeMinutes;
  final List<Subject> candidateSubjects;
  final String? initialSubjectId;
  final bool askWhichSession;
  const _LogSheet({
    required this.current,
    required this.quarterIndex,
    required this.blockSizeMinutes,
    required this.candidateSubjects,
    required this.initialSubjectId,
    required this.askWhichSession,
  });

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  String? _subjectId;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
  }

  String get _heading {
    final size = widget.blockSizeMinutes;
    final span = size == 60 ? 'hour' : '$size minutes';
    return 'How focused were you the past $span?';
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
      Utilization.notFocus,
      Utilization.none,
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(R.pill),
                  ),
                ),
              ),
              const SizedBox(height: Sp.md),
              Text(_heading, style: AppText.headline.copyWith(color: t.ink)),
              const SizedBox(height: 2),
              Text(
                quarterLabel(widget.quarterIndex,
                    blockSizeMinutes: widget.blockSizeMinutes),
                style: AppText.label.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: Sp.md),
              if (widget.candidateSubjects.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      widget.askWhichSession ? 'WHICH SESSION' : 'SUBJECT',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: t.inkMuted),
                    ),
                    if (widget.askWhichSession) ...[
                      const SizedBox(width: Sp.s),
                      Icon(LucideIcons.triangleAlert,
                          color: t.accent, size: 14),
                    ],
                  ],
                ),
                if (widget.askWhichSession) ...[
                  const SizedBox(height: Sp.xs),
                  Text(
                    'Two or more sessions overlap this block. Tell us which one this belongs to.',
                    style: AppText.label.copyWith(color: t.accent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: Sp.s),
                Wrap(
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    _SubjectChip(
                      label: 'No subject',
                      selected: _subjectId == null,
                      onTap: () => setState(() => _subjectId = null),
                    ),
                    for (final s in widget.candidateSubjects)
                      _SubjectChip(
                        label: s.name,
                        selected: _subjectId == s.id,
                        onTap: () => setState(() => _subjectId = s.id),
                      ),
                  ],
                ),
                const SizedBox(height: Sp.md),
              ],
              for (final u in options)
                _Row(
                  util: u,
                  selected: u == widget.current,
                  onTap: () => Navigator.of(context).pop(
                    LogBlockResult(
                      utilization: u,
                      subjectId: _subjectId,
                      clearSubjectId: _subjectId == null,
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

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubjectChip({
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

class _Row extends StatelessWidget {
  final Utilization util;
  final bool selected;
  final VoidCallback onTap;
  const _Row({required this.util, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final swatchColor = util == Utilization.none ? Colors.transparent : util.color(t);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Sp.xs),
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.m),
        decoration: BoxDecoration(
          color: selected ? t.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: selected ? t.ink : t.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: swatchColor,
                borderRadius: BorderRadius.circular(R.xs),
                border: util == Utilization.none ? Border.all(color: t.divider) : null,
              ),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(util.focusLabel, style: AppText.bodyStrong.copyWith(color: t.ink)),
            ),
            if (util.percent != null)
              Text('${util.percent}%', style: AppText.label.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

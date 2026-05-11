import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../subjects/subject_edit_sheet.dart';

/// Per-weekday focus targets. The user can set a different number of minutes
/// for each day (e.g. lighter weekends, all-out weekdays). Numeric input is
/// clamped 0..1440 (24 hours), so a SAT/GRE-prep user can set 720 min (12 hr)
/// without fighting the UI.
class FocusMinimumScreen extends StatefulWidget {
  const FocusMinimumScreen({super.key});

  @override
  State<FocusMinimumScreen> createState() => _FocusMinimumScreenState();
}

class _FocusMinimumScreenState extends State<FocusMinimumScreen> {
  static const _names = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  late List<TextEditingController> _ctls;
  late List<int> _values;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _ctls = List.generate(7, (_) => TextEditingController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final profile = AppServices.of(context).profile.profile.value;
    final mins = profile.weeklyFocusMinutes.length == 7
        ? profile.weeklyFocusMinutes
        : List.filled(7, 240);
    _values = List<int>.from(mins);
    for (var i = 0; i < 7; i++) {
      _ctls[i].text = _values[i].toString();
    }
    _seeded = true;
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _persist() async {
    final svc = AppServices.of(context);
    final p = svc.profile.profile.value;
    await svc.profile.update(p.copyWith(weeklyFocusMinutes: List<int>.from(_values)));
  }

  void _setValue(int i, int v) {
    setState(() {
      _values[i] = v.clamp(0, 1440);
      // Keep the controller in sync only when the value changed by clamping;
      // otherwise leave it alone so the user can keep typing.
      if (_ctls[i].text != _values[i].toString() &&
          int.tryParse(_ctls[i].text) != _values[i]) {
        _ctls[i].text = _values[i].toString();
      }
    });
  }

  String _hours(int mins) {
    if (mins == 0) return 'rest day';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now().weekday;
    final weeklyTotal = _values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Focus targets'),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _persist();
              if (mounted) navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
        children: [
          AppCard(
            color: t.ink,
            padding: const EdgeInsets.all(Sp.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEEKLY TOTAL',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: t.bg.withValues(alpha: 0.6))),
                const SizedBox(height: Sp.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_hours(weeklyTotal),
                        style: AppText.big.copyWith(color: t.bg, fontSize: 36)),
                    const SizedBox(width: Sp.s),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.xs),
                      child: Text('across 7 days',
                          style: AppText.title
                              .copyWith(color: t.bg.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.md),
          Text('PER WEEKDAY (0..1440 min)',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.s),
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _DayRow(
                name: _names[i],
                isToday: (i + 1) == today,
                value: _values[i],
                hoursLabel: _hours(_values[i]),
                controller: _ctls[i],
                onChanged: (raw) {
                  final n = int.tryParse(raw);
                  if (n == null) return;
                  _setValue(i, n);
                },
                onBump: (delta) => _setValue(i, _values[i] + delta),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String name;
  final bool isToday;
  final int value;
  final String hoursLabel;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final void Function(int) onBump;
  const _DayRow({
    required this.name,
    required this.isToday,
    required this.value,
    required this.hoursLabel,
    required this.controller,
    required this.onChanged,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: isToday ? t.accent : t.divider),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                if (isToday)
                  Text('TODAY',
                      style: AppText.label.copyWith(
                        color: t.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.minus),
            onPressed: () => onBump(-15),
            tooltip: '-15 min',
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: AppText.mono.copyWith(
                color: t.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => onBump(15),
            tooltip: '+15 min',
          ),
          const Spacer(),
          Text(hoursLabel,
              style: AppText.label.copyWith(color: t.inkMuted)),
        ],
      ),
    );
  }
}

class AlarmSoundScreen extends StatelessWidget {
  const AlarmSoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Quarter alarm sound')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, s, __) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plays at every accountability tick during an active subject block, so you log without breaking flow.',
                    style: AppText.body.copyWith(color: t.inkMuted),
                  ),
                  const SizedBox(height: Sp.s),
                  Text(
                    'You will hear the chosen sound at the next reminder. Bundled sounds are CC-BY 3.0 / CC-BY-SA 3.0.',
                    style: AppText.label.copyWith(color: t.inkMuted),
                  ),
                  const SizedBox(height: Sp.s),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.bellRing),
                      label: const Text('Send a test notification'),
                      onPressed: () async {
                        await svc.notifications.sendTestNotification(s.alarm);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sent. Check your notification shade.')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            for (final a in AlarmSound.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: AppCard(
                  onTap: () => svc.settings.update(s.copyWith(alarm: a)),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
                  child: Row(
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: a == s.alarm ? t.ink : t.divider, width: 2),
                          color: a == s.alarm ? t.ink : Colors.transparent,
                        ),
                        child: a == s.alarm
                            ? Center(
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(child: Text(a.label, style: AppText.bodyStrong.copyWith(color: t.ink))),
                      if (a != AlarmSound.none)
                        IconButton(
                          tooltip: 'Preview',
                          icon: const Icon(LucideIcons.play),
                          onPressed: () async {
                            await svc.notifications.sendTestNotification(a);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sent a "${a.label}" preview to your notification shade.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
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

class FirstDayScreen extends StatelessWidget {
  const FirstDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('First day of week')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, s, __) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          children: [
            for (final d in FirstDayOfWeek.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: AppCard(
                  onTap: () => svc.settings.update(s.copyWith(firstDay: d)),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
                  child: Row(
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: d == s.firstDay ? t.ink : t.divider, width: 2),
                          color: d == s.firstDay ? t.ink : Colors.transparent,
                        ),
                        child: d == s.firstDay
                            ? Center(
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(
                        child: Text(
                          switch (d) {
                            FirstDayOfWeek.monday => 'Monday',
                            FirstDayOfWeek.sunday => 'Sunday',
                            FirstDayOfWeek.saturday => 'Saturday',
                          },
                          style: AppText.bodyStrong.copyWith(color: t.ink),
                        ),
                      ),
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

class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Archived habits')),
      body: ValueListenableBuilder<List<Habit>>(
        valueListenable: svc.habits.all,
        builder: (_, all, __) {
          final archived = all.where((h) => h.archived).toList();
          if (archived.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Sp.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.archive, color: t.inkMuted, size: 40),
                    const SizedBox(height: Sp.m),
                    Text('Nothing archived', style: AppText.title.copyWith(color: t.ink)),
                    const SizedBox(height: Sp.xs),
                    Text(
                      'Habits you stop tracking show up here. Archive a habit from its edit sheet.',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: t.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
            itemCount: archived.length,
            separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
            itemBuilder: (_, i) {
              final h = archived[i];
              return AppCard(
                padding: const EdgeInsets.all(Sp.md),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(R.s),
                        border: Border.all(color: t.divider),
                      ),
                      alignment: Alignment.center,
                      child: Icon(h.glyph, color: t.inkMuted, size: IconSize.m),
                    ),
                    const SizedBox(width: Sp.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                          Text('Best streak ${h.bestStreak} days  ·  ${h.completionRate}%',
                              style: AppText.label.copyWith(color: t.inkMuted)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => svc.habits.unarchive(h.id),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: Sp.m),
                      ),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PrivacyLockScreen extends StatelessWidget {
  const PrivacyLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Privacy lock')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, s, __) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          children: [
            AppCard(
              padding: const EdgeInsets.all(Sp.md),
              child: Row(
                children: [
                  Icon(LucideIcons.shield, color: t.ink, size: IconSize.l),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Require unlock to open', style: AppText.bodyStrong.copyWith(color: t.ink)),
                        Text('Biometric or PIN. Mocked for now.',
                            style: AppText.label.copyWith(color: t.inkMuted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: s.privacyLockOn,
                    onChanged: (v) => svc.settings.update(s.copyWith(privacyLockOn: v)),
                    activeThumbColor: t.accent,
                  ),
                ],
              ),
            ),
            if (s.privacyLockOn) ...[
              const SizedBox(height: Sp.m),
              AppCard(
                padding: const EdgeInsets.all(Sp.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNLOCK METHOD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                    const SizedBox(height: Sp.s),
                    Row(
                      children: [
                        for (final method in const ['Biometric', 'PIN', 'Both'])
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(Sp.xs),
                              padding: const EdgeInsets.symmetric(vertical: Sp.s),
                              decoration: BoxDecoration(
                                color: method == 'Biometric' ? t.ink : t.surfaceAlt,
                                borderRadius: BorderRadius.circular(R.s),
                                border: Border.all(color: t.divider),
                              ),
                              alignment: Alignment.center,
                              child: Text(method.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: method == 'Biometric' ? t.bg : t.ink,
                                      )),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Global pomodoro defaults. Each [SubjectBlock] also has its own
/// `pomodoroEnabled` / `pomodoroPercent` field; the per-block setting takes
/// precedence so the user can tune individual blocks. The percent here is
/// the default applied to new blocks AND the value shown when the floating
/// dialog asks "do you want pomodoro for this block?".
class PomodoroSettingsScreen extends StatelessWidget {
  const PomodoroSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Pomodoro')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, s, __) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          children: [
            AppCard(
              padding: const EdgeInsets.all(Sp.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Default: pomodoro on for new blocks',
                                style: AppText.bodyStrong.copyWith(color: t.ink)),
                            const SizedBox(height: 2),
                            Text(
                              'New blocks will start with this setting. You can override per block from the floating timer or the subject editor.',
                              style: AppText.label.copyWith(color: t.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: s.pomodoroEnabled,
                        onChanged: (v) =>
                            svc.settings.update(s.copyWith(pomodoroEnabled: v)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            AppCard(
              padding: const EdgeInsets.all(Sp.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REST PERCENT (default for new blocks)',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: t.inkMuted)),
                  const SizedBox(height: Sp.s),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${s.pomodoroPercent}',
                          style: AppText.display
                              .copyWith(color: t.ink, fontSize: 36)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('% of each block',
                            style: AppText.label.copyWith(color: t.inkMuted)),
                      ),
                    ],
                  ),
                  Slider(
                    min: 5,
                    max: 50,
                    divisions: 9,
                    value: s.pomodoroPercent.toDouble().clamp(5, 50),
                    label: '${s.pomodoroPercent}%',
                    onChanged: (v) => svc.settings
                        .update(s.copyWith(pomodoroPercent: v.round())),
                  ),
                  Text(
                    'Example: a 60 min block at ${s.pomodoroPercent}% gives ${(60 * s.pomodoroPercent / 100).round()} min of rest at the end.',
                    style: AppText.label.copyWith(color: t.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global block-size picker. The Time tab no longer has its own toggle; this
/// is the single place to switch between 15 / 30 / 60 minute logging blocks.
/// Storage stays at 15-minute quarters; this only affects how the grid is
/// rendered and how often accountability ticks fire.
class BlockSizeScreen extends StatelessWidget {
  const BlockSizeScreen({super.key});

  static const List<({int value, String label, String hint})> _options = [
    (
      value: 15,
      label: '15 minutes',
      hint: 'Most granular. Four cells per hour, four ticks per hour.',
    ),
    (
      value: 30,
      label: '30 minutes',
      hint: 'Balanced. Two cells per hour, two ticks per hour.',
    ),
    (
      value: 60,
      label: '1 hour',
      hint: 'Lightest cadence. One cell per hour, one tick per hour.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Logging block size')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, s, __) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.m),
              child: Text(
                'How often the time tracker asks you to log. Same setting drives the grid layout, the accountability ticks, and the floating timer countdown. Storage stays at 15-min sub-blocks so switching back any time is non-destructive.',
                style: AppText.body.copyWith(color: t.inkMuted),
              ),
            ),
            for (final opt in _options)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: AppCard(
                  onTap: () => svc.settings
                      .update(s.copyWith(blockSizeMinutes: opt.value)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: Sp.md, vertical: Sp.m),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: opt.value == s.blockSizeMinutes
                                ? t.ink
                                : t.divider,
                            width: 2,
                          ),
                          color: opt.value == s.blockSizeMinutes
                              ? t.ink
                              : Colors.transparent,
                        ),
                        child: opt.value == s.blockSizeMinutes
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: t.bg, shape: BoxShape.circle),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.label,
                                style:
                                    AppText.bodyStrong.copyWith(color: t.ink)),
                            Text(opt.hint,
                                style: AppText.label
                                    .copyWith(color: t.inkMuted)),
                          ],
                        ),
                      ),
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

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Subjects')),
      body: ValueListenableBuilder<List<Subject>>(
        valueListenable: svc.subjects.all,
        builder: (_, subjects, __) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          itemCount: subjects.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
          itemBuilder: (_, i) {
            if (i == 0) {
              return InkWell(
                onTap: () => showSubjectEditSheet(context),
                borderRadius: BorderRadius.circular(R.s),
                child: Container(
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(R.s),
                    border: Border.all(color: t.ink, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(R.s)),
                        alignment: Alignment.center,
                        child: Icon(LucideIcons.plus, color: t.bg, size: IconSize.m),
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add a subject',
                                style: AppText.bodyStrong.copyWith(color: t.ink)),
                            Text('A label you tag focus sessions and time blocks with',
                                style: AppText.label.copyWith(color: t.inkMuted)),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
                    ],
                  ),
                ),
              );
            }
            final s = subjects[i - 1];
            return AppCard(
              onTap: () => showSubjectEditSheet(context, existing: s),
              padding: const EdgeInsets.all(Sp.md),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: BorderRadius.circular(R.s),
                      border: Border.all(color: t.divider),
                    ),
                    alignment: Alignment.center,
                    child: Icon(LucideIcons.bookmark, color: t.ink, size: IconSize.m),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Text(s.name,
                        style: AppText.bodyStrong.copyWith(color: t.ink)),
                  ),
                  Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

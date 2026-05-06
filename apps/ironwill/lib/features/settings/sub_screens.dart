import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../sessions/session_edit_sheet.dart';

class FocusMinimumScreen extends StatelessWidget {
  const FocusMinimumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    final options = const [60, 90, 120, 150, 180, 210, 240, 300, 360, 480];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Daily focus minimum')),
      body: ValueListenableBuilder<UserProfile>(
        valueListenable: svc.profile.profile,
        builder: (_, p, __) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          children: [
            AppCard(
              color: t.ink,
              padding: const EdgeInsets.all(Sp.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT TARGET',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.bg.withValues(alpha: 0.6))),
                  const SizedBox(height: Sp.s),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${p.dailyFocusMinutesTarget}',
                          style: AppText.big.copyWith(color: t.bg, fontSize: 56)),
                      const SizedBox(width: Sp.s),
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.s),
                        child: Text('min per day',
                            style: AppText.title.copyWith(color: t.bg.withValues(alpha: 0.6))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            Text('PRESETS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
            const SizedBox(height: Sp.s),
            for (final m in options)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: AppCard(
                  onTap: () => svc.profile.update(p.copyWith(dailyFocusMinutesTarget: m)),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
                  child: Row(
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: m == p.dailyFocusMinutesTarget ? t.ink : t.divider, width: 2),
                          color: m == p.dailyFocusMinutesTarget ? t.ink : Colors.transparent,
                        ),
                        child: m == p.dailyFocusMinutesTarget
                            ? Center(
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(child: Text('$m min', style: AppText.bodyStrong.copyWith(color: t.ink))),
                      Text('${(m / 60).toStringAsFixed(1)}h', style: AppText.mono.copyWith(color: t.inkMuted)),
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
                    'Plays at the end of each quarter inside an active focus session, so you log without breaking flow.',
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

class FocusSessionsScreen extends StatelessWidget {
  const FocusSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Focus sessions')),
      body: ValueListenableBuilder<List<FocusSession>>(
        valueListenable: svc.sessions.all,
        builder: (_, sessions, __) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
          itemCount: sessions.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
          itemBuilder: (_, i) {
            if (i == 0) {
              return InkWell(
                onTap: () => showSessionEditSheet(context),
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
                            Text('Add a focus session',
                                style: AppText.bodyStrong.copyWith(color: t.ink)),
                            Text('Name, start, end, days',
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
            final s = sessions[i - 1];
            final daysLabel = s.daysOfWeek.length == 7
                ? 'Every day'
                : s.daysOfWeek.length == 5 && !s.daysOfWeek.contains(6) && !s.daysOfWeek.contains(7)
                    ? 'Weekdays'
                    : s.daysOfWeek
                        .map((d) => const ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'][d])
                        .join(' ');
            return AppCard(
              onTap: () => showSessionEditSheet(context, existing: s),
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
                    child: Icon(LucideIcons.target, color: t.ink, size: IconSize.m),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                        Text(
                          '${s.start.format24()} to ${s.end.format24()}  ·  $daysLabel',
                          style: AppText.label.copyWith(color: t.inkMuted),
                        ),
                      ],
                    ),
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

extension on TimeOfDay {
  String format24() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

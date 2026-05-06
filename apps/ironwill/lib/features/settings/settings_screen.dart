import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_theme_controller.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../profile/profile_edit_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Settings', style: AppText.headline.copyWith(color: t.ink)),
      ),
      body: ValueListenableBuilder<UserProfile>(
        valueListenable: svc.profile.profile,
        builder: (_, profile, __) => ValueListenableBuilder<AppSettings>(
          valueListenable: svc.settings.settings,
          builder: (_, s, __) => ListView(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
            children: [
              _ProfileCard(profile: profile),
              const SizedBox(height: Sp.lg),
              const _SectionTitle('Appearance'),
              const _ThemeRow(),
              const SizedBox(height: Sp.lg),
              const _SectionTitle('Focus'),
              _SimpleRow(
                icon: LucideIcons.target,
                label: 'Daily focus minimum',
                trailing: '${profile.dailyFocusMinutesTarget} min',
                onTap: () => context.push('/settings/focus-minimum'),
              ),
              _SimpleRow(
                icon: LucideIcons.bellRing,
                label: 'Quarter alarm sound',
                trailing: s.alarm.label,
                onTap: () => context.push('/settings/alarm'),
              ),
              _SimpleRow(
                icon: LucideIcons.bell,
                label: 'Logging reminders',
                trailing: s.reminderLogging ? 'On' : 'Off',
                onTap: () => svc.settings.update(s.copyWith(reminderLogging: !s.reminderLogging)),
              ),
              _SimpleRow(
                icon: LucideIcons.clockArrowUp,
                label: 'Focus sessions',
                trailing: 'Manage',
                onTap: () => context.push('/settings/sessions'),
              ),
              const SizedBox(height: Sp.lg),
              const _SectionTitle('Habits'),
              _SimpleRow(
                icon: LucideIcons.calendarRange,
                label: 'First day of week',
                trailing: switch (s.firstDay) {
                  FirstDayOfWeek.monday => 'Monday',
                  FirstDayOfWeek.sunday => 'Sunday',
                  FirstDayOfWeek.saturday => 'Saturday',
                },
                onTap: () => context.push('/settings/first-day'),
              ),
              _SimpleRow(
                icon: LucideIcons.archive,
                label: 'Archived habits',
                trailing: '',
                onTap: () => context.push('/settings/archived'),
              ),
              const SizedBox(height: Sp.lg),
              const _SectionTitle('Account'),
              _SimpleRow(
                icon: LucideIcons.user,
                label: 'Profile',
                trailing: 'Edit',
                onTap: () => showProfileEditSheet(context),
              ),
              _SimpleRow(
                icon: LucideIcons.cloud,
                label: 'Sync',
                trailing: 'Coming soon',
                onTap: () {},
              ),
              _SimpleRow(
                icon: LucideIcons.shield,
                label: 'Privacy lock',
                trailing: s.privacyLockOn ? 'On' : 'Off',
                onTap: () => context.push('/settings/privacy-lock'),
              ),
              const SizedBox(height: Sp.lg),
              const _SectionTitle('Backup'),
              _SimpleRow(
                icon: LucideIcons.upload,
                label: 'Export data',
                trailing: 'JSON',
                onTap: () => _exportData(context),
              ),
              _SimpleRow(
                icon: LucideIcons.download,
                label: 'Import data',
                trailing: 'Replace',
                onTap: () => _importData(context),
              ),
              const SizedBox(height: Sp.lg),
              const _SectionTitle('About'),
              _SimpleRow(icon: LucideIcons.info, label: 'Version', trailing: '1.0', onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final svc = AppServices.of(context);
    final backup = svc.backup;
    if (backup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup is not available in this build.')),
      );
      return;
    }
    try {
      await backup.shareExport();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    final svc = AppServices.of(context);
    final backup = svc.backup;
    if (backup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import is not available in this build.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Importing will overwrite every habit, log, time block, and setting. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    try {
      final picked = await backup.pickAndImport();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(picked ? 'Import complete. Restart for full effect.' : 'Cancelled.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      onTap: () => showProfileEditSheet(context),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: t.ink,
              borderRadius: BorderRadius.circular(R.s),
            ),
            alignment: Alignment.center,
            child: Text(
              (profile.avatarLetter ?? profile.name.substring(0, 1)).toUpperCase(),
              style: AppText.headline.copyWith(color: t.bg, fontSize: 22),
            ),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: AppText.title.copyWith(color: t.ink)),
                Text('Daily focus minimum  ·  ${profile.dailyFocusMinutesTarget} min',
                    style: AppText.label.copyWith(color: t.inkMuted)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.md, Sp.xs, Sp.s),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppThemeController.of(context);
    final t = context.tokens;
    Widget chip(ThemeMode m, String label, IconData icon) {
      final selected = ctrl.mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => ctrl.setMode(m),
          child: Container(
            margin: const EdgeInsets.all(Sp.xs),
            padding: const EdgeInsets.symmetric(vertical: Sp.m),
            decoration: BoxDecoration(
              color: selected ? t.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(R.s),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? t.bg : t.ink, size: IconSize.l),
                const SizedBox(height: Sp.xs),
                Text(label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected ? t.bg : t.ink,
                        )),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(Sp.s),
      child: Row(
        children: [
          chip(ThemeMode.light, 'Light', LucideIcons.sun),
          chip(ThemeMode.dark, 'Dark', LucideIcons.moon),
          chip(ThemeMode.system, 'System', LucideIcons.monitor),
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback onTap;
  const _SimpleRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.m),
        child: Row(
          children: [
            Icon(icon, color: t.ink, size: IconSize.m),
            const SizedBox(width: Sp.m),
            Expanded(child: Text(label, style: AppText.bodyStrong.copyWith(color: t.ink))),
            if (trailing.isNotEmpty)
              Text(trailing, style: AppText.label.copyWith(color: t.inkMuted)),
            const SizedBox(width: Sp.s),
            Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../habits/habit_edit_sheet.dart';
import '../subjects/subject_edit_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  int _focusTarget = 240;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final svc = AppServices.of(context);
    final s = svc.settings.settings.value;
    final p = svc.profile.profile.value;
    final firstLetter = _name.text.trim().isNotEmpty
        ? _name.text.trim().substring(0, 1).toUpperCase()
        : null;
    // Onboarding picks one daily target and seeds all 7 weekdays from it.
    // The user can break out per-day later in Settings → Focus targets.
    await svc.profile.update(p.copyWith(
      name: _name.text.trim().isEmpty ? p.name : _name.text.trim(),
      weeklyFocusMinutes: List<int>.filled(7, _focusTarget),
      avatarLetter: firstLetter ?? p.avatarLetter,
    ));
    await svc.settings.update(s.copyWith(
      onboarded: true,
      dailyFocusMinutes: _focusTarget,
    ));
    if (mounted) context.go('/today');
  }

  Future<void> _skipAll() async {
    final svc = AppServices.of(context);
    await svc.settings.update(svc.settings.settings.value.copyWith(onboarded: true));
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, 0),
              child: Row(
                children: [
                  Text('LOCKEDIN',
                      style: AppText.section.copyWith(color: t.inkMuted, letterSpacing: 2.4)),
                  const Spacer(),
                  TextButton(onPressed: _skipAll, child: const Text('Skip setup')),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                children: [
                  _Welcome(onNext: () => _go(1)),
                  _NamePage(controller: _name, onNext: () => _go(2)),
                  _FocusTargetPage(
                    target: _focusTarget,
                    onChange: (v) => setState(() => _focusTarget = v),
                    onNext: () => _go(3),
                  ),
                  _FirstHabitPage(onNext: () => _go(4)),
                  _FirstSessionPage(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(int page) {
    _page.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }
}

class _Welcome extends StatelessWidget {
  final VoidCallback onNext;
  const _Welcome({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(R.s),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.flame, color: t.accentInk, size: IconSize.xl),
          ),
          const SizedBox(height: Sp.lg),
          Text("Show up.\nMeasure it.\nDon't break the chain.",
              style: AppText.headline.copyWith(color: t.ink, fontSize: 32, height: 1.15)),
          const SizedBox(height: Sp.md),
          Text(
            'LockedIn tracks two things: how much of each focus block you actually used, and which habits you held the line on. Everything stays on this device. You can export your data any time.',
            style: AppText.body.copyWith(color: t.inkMuted, fontSize: 16),
          ),
          const SizedBox(height: Sp.x3l),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text("Let's go")),
          ),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  const _NamePage({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP 1 / 4', style: AppText.section.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.s),
          Text('What should we call you?',
              style: AppText.headline.copyWith(color: t.ink, fontSize: 28)),
          const SizedBox(height: Sp.m),
          Text(
            "First name only. We use it on the Today screen and for the avatar initial. You can change it later.",
            style: AppText.body.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.lg),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onNext(),
            style: AppText.body.copyWith(color: t.ink, fontSize: 18),
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

class _FocusTargetPage extends StatefulWidget {
  final int target;
  final ValueChanged<int> onChange;
  final VoidCallback onNext;
  const _FocusTargetPage({
    required this.target,
    required this.onChange,
    required this.onNext,
  });

  @override
  State<_FocusTargetPage> createState() => _FocusTargetPageState();
}

class _FocusTargetPageState extends State<_FocusTargetPage> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.target.toString());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _commit(int v) {
    final clamped = v.clamp(0, 1440);
    widget.onChange(clamped);
    if (int.tryParse(_ctl.text) != clamped) {
      _ctl.text = clamped.toString();
    }
  }

  String _hours(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP 2 / 4', style: AppText.section.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.s),
          Text('How many minutes of real focus do you want to land per day?',
              style: AppText.headline.copyWith(color: t.ink, fontSize: 26, height: 1.2)),
          const SizedBox(height: Sp.m),
          Text(
            "We'll use this as the daily floor for your focus streak. Type any number from 0 to 1440 (24 hours). You can break it out per weekday later in Settings.",
            style: AppText.body.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.lg),
          AppCard(
            color: t.ink,
            stroked: false,
            padding: const EdgeInsets.all(Sp.lg),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(LucideIcons.minus, color: t.bg),
                  onPressed: () => _commit(widget.target - 15),
                  tooltip: '-15 min',
                ),
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: AppText.big.copyWith(color: t.bg, fontSize: 48),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '240',
                      hintStyle: AppText.big.copyWith(
                        color: t.bg.withValues(alpha: 0.3),
                        fontSize: 48,
                      ),
                    ),
                    onChanged: (raw) {
                      final n = int.tryParse(raw);
                      if (n != null) _commit(n);
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.plus, color: t.bg),
                  onPressed: () => _commit(widget.target + 15),
                  tooltip: '+15 min',
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.s),
          Text('= ${_hours(widget.target)} per day',
              style: AppText.label.copyWith(color: t.inkMuted)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: widget.onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

class _FirstHabitPage extends StatelessWidget {
  final VoidCallback onNext;
  const _FirstHabitPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP 3 / 4', style: AppText.section.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.s),
          Text('Add your first habit.',
              style: AppText.headline.copyWith(color: t.ink, fontSize: 26)),
          const SizedBox(height: Sp.m),
          Text(
            "Pick something small you can do every day. Cold shower. No social before noon. Walk 30 minutes. You can add more later.",
            style: AppText.body.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.lg),
          OutlinedButton.icon(
            onPressed: () => showHabitEditSheet(context),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add a habit'),
          ),
          const SizedBox(height: Sp.md),
          Expanded(
            child: ValueListenableBuilder<List<Habit>>(
              valueListenable: svc.habits.active,
              builder: (_, habits, __) {
                if (habits.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListView.separated(
                  itemCount: habits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
                  itemBuilder: (_, i) {
                    final h = habits[i];
                    return AppCard(
                      onTap: () => showHabitEditSheet(context, existing: h),
                      padding: const EdgeInsets.all(Sp.m),
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
                            child: Icon(h.glyph, color: t.ink, size: IconSize.m),
                          ),
                          const SizedBox(width: Sp.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                                Text(h.cadence.label,
                                    style: AppText.label.copyWith(color: t.inkMuted)),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.pencil, color: t.inkMuted, size: IconSize.s),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onNext, child: const Text('Continue')),
          ),
          const SizedBox(height: Sp.s),
          Center(
            child: TextButton(
              onPressed: onNext,
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstSessionPage extends StatelessWidget {
  final VoidCallback onFinish;
  const _FirstSessionPage({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return _OnboardingPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEP 4 / 4', style: AppText.section.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.s),
          Text('Pick your first subject.',
              style: AppText.headline.copyWith(color: t.ink, fontSize: 26)),
          const SizedBox(height: Sp.m),
          Text(
            "A subject is what you're locking in on (Math, Workout, a side project). It runs on a weekly schedule and you log your focus inside each block. You can add more later.",
            style: AppText.body.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.lg),
          OutlinedButton.icon(
            onPressed: () => showSubjectEditSheet(context),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add a subject'),
          ),
          const SizedBox(height: Sp.md),
          Expanded(
            child: ValueListenableBuilder<List<Subject>>(
              valueListenable: svc.subjects.all,
              builder: (_, subjects, __) {
                if (subjects.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListView.separated(
                  itemCount: subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
                  itemBuilder: (_, i) {
                    final s = subjects[i];
                    final blockCount = s.blocks.length;
                    final summary = blockCount == 0
                        ? 'No blocks scheduled yet'
                        : '$blockCount block${blockCount == 1 ? '' : 's'} this week';
                    return AppCard(
                      onTap: () => showSubjectEditSheet(context, existing: s),
                      padding: const EdgeInsets.all(Sp.m),
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
                                Text(summary, style: AppText.label.copyWith(color: t.inkMuted)),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.pencil, color: t.inkMuted, size: IconSize.s),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onFinish, child: const Text('Finish setup')),
          ),
          const SizedBox(height: Sp.s),
          Center(
            child: TextButton(onPressed: onFinish, child: const Text('Finish without one')),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final Widget child;
  const _OnboardingPage({required this.child});

  @override
  Widget build(BuildContext context) {
    // Wrap in a scroll view that respects the available height. When the
    // keyboard opens (e.g. on the name-input page), content can scroll
    // instead of overflowing by `bottom overflowed by N pixels`.
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.x3l, Sp.md, Sp.x3l),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - Sp.x3l * 2,
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

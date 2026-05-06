import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../habits/habit_edit_sheet.dart';
import '../sessions/session_edit_sheet.dart';

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
    await svc.profile.update(p.copyWith(
      name: _name.text.trim().isEmpty ? p.name : _name.text.trim(),
      dailyFocusMinutesTarget: _focusTarget,
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
                  Text('IRONWILL',
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
            'IronWill tracks two things: how much of each focus block you actually used, and which habits you held the line on. Everything stays on this device. You can export your data any time.',
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

class _FocusTargetPage extends StatelessWidget {
  final int target;
  final ValueChanged<int> onChange;
  final VoidCallback onNext;
  const _FocusTargetPage({
    required this.target,
    required this.onChange,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final options = const [60, 120, 180, 240, 300, 360, 480];
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
            "We use this as the daily floor for your focus streak. Pick something hard but truthful.",
            style: AppText.body.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.lg),
          AppCard(
            color: t.ink,
            stroked: false,
            padding: const EdgeInsets.all(Sp.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$target', style: AppText.big.copyWith(color: t.bg, fontSize: 56)),
                const SizedBox(width: Sp.s),
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.s),
                  child: Text('min',
                      style: AppText.title.copyWith(color: t.bg.withValues(alpha: 0.6))),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            children: [
              for (final m in options)
                GestureDetector(
                  onTap: () => onChange(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
                    decoration: BoxDecoration(
                      color: m == target ? t.ink : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(R.s),
                      border: Border.all(color: t.divider),
                    ),
                    child: Text('$m min',
                        style: AppText.bodyStrong.copyWith(
                          color: m == target ? t.bg : t.ink,
                        )),
                  ),
                ),
            ],
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
          Text('Schedule a focus session.',
              style: AppText.headline.copyWith(color: t.ink, fontSize: 26)),
          const SizedBox(height: Sp.m),
          Text(
            "While a focus session is running you'll get a soft alarm at every 15 minute mark to log how the quarter actually went. Two hours of true focus per day beats six hours of pretending.",
            style: AppText.body.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.lg),
          OutlinedButton.icon(
            onPressed: () => showSessionEditSheet(context),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add a session'),
          ),
          const SizedBox(height: Sp.md),
          Expanded(
            child: ValueListenableBuilder<List<FocusSession>>(
              valueListenable: svc.sessions.all,
              builder: (_, sessions, __) {
                if (sessions.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
                  itemBuilder: (_, i) {
                    final s = sessions[i];
                    final timeLabel =
                        '${s.start.hour.toString().padLeft(2, '0')}:${s.start.minute.toString().padLeft(2, '0')} to ${s.end.hour.toString().padLeft(2, '0')}:${s.end.minute.toString().padLeft(2, '0')}';
                    return AppCard(
                      onTap: () => showSessionEditSheet(context, existing: s),
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
                                Text(timeLabel, style: AppText.label.copyWith(color: t.inkMuted)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.x3l, Sp.md, Sp.x3l),
      child: child,
    );
  }
}

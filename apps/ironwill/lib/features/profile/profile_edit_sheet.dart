import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

Future<void> showProfileEditSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surface,
    builder: (ctx) => const _ProfileEditSheet(),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet();
  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _name = TextEditingController();
  int _target = 240;
  UserProfile? _initial;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final p = AppServices.of(context).profile.profile.value;
    _initial = p;
    _name.text = p.name;
    _target = p.dailyFocusMinutesTarget;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final initial = _initial;
    if (initial == null) return;
    await AppServices.of(context).profile.update(
          initial.copyWith(
            name: _name.text.trim().isEmpty ? initial.name : _name.text.trim(),
            dailyFocusMinutesTarget: _target,
            avatarLetter: _name.text.trim().isEmpty
                ? initial.avatarLetter
                : _name.text.trim().substring(0, 1).toUpperCase(),
          ),
        );
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
                  Expanded(child: Text('Edit profile', style: AppText.headline.copyWith(color: t.ink))),
                  IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: Sp.md),
              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Sp.x3l),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Text('NAME',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                const SizedBox(height: Sp.s),
                TextField(
                  controller: _name,
                  style: AppText.body.copyWith(color: t.ink, fontSize: 16),
                  decoration: const InputDecoration(hintText: 'Your name'),
                ),
                const SizedBox(height: Sp.lg),
                Text('DAILY FOCUS MINIMUM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                const SizedBox(height: Sp.s),
                _Stepper(
                  value: _target,
                  step: 15,
                  min: 30,
                  max: 720,
                  onChange: (v) => setState(() => _target = v),
                  suffix: 'min per day',
                ),
                const SizedBox(height: Sp.x3l),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: _save, child: const Text('Save profile')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChange;
  final String suffix;
  const _Stepper({
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.onChange,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        children: [
          _StepperButton(icon: LucideIcons.minus, onTap: () => onChange((value - step).clamp(min, max))),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(value.toString(), style: AppText.display.copyWith(color: t.ink, fontSize: 28)),
                  Text(suffix, style: AppText.label.copyWith(color: t.inkMuted)),
                ],
              ),
            ),
          ),
          _StepperButton(icon: LucideIcons.plus, onTap: () => onChange((value + step).clamp(min, max))),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        child: Icon(icon, color: t.ink, size: IconSize.m),
      ),
    );
  }
}

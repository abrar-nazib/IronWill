import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';

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
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final initial = _initial;
    if (initial == null) return;
    final navigator = Navigator.of(context);
    await AppServices.of(context).profile.update(
          initial.copyWith(
            name: _name.text.trim().isEmpty ? initial.name : _name.text.trim(),
            avatarLetter: _name.text.trim().isEmpty
                ? initial.avatarLetter
                : _name.text.trim().substring(0, 1).toUpperCase(),
          ),
        );
    if (mounted) navigator.pop();
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
                AppCard(
                  padding: const EdgeInsets.all(Sp.md),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/settings/focus-minimum');
                  },
                  child: Row(
                    children: [
                      Icon(LucideIcons.target, color: t.ink, size: IconSize.m),
                      const SizedBox(width: Sp.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Focus targets',
                                style: AppText.bodyStrong.copyWith(color: t.ink)),
                            Text("Today's target: ${_initial!.targetForToday()} min",
                                style: AppText.label.copyWith(color: t.inkMuted)),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight,
                          color: t.inkMuted, size: IconSize.s),
                    ],
                  ),
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

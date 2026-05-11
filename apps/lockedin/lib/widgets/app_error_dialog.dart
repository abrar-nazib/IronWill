import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Brand-aligned blocking error dialog. Uses the ember accent + a
/// prominent vector icon (in place of emoji, per the brand guide) so
/// errors look unmistakable next to the rest of the UI without going
/// cartoon. Use this everywhere the old AlertDialog-based `_showError`
/// helpers lived: collisions, validation failures, anything the user
/// must acknowledge before proceeding.
///
/// Returns a Future that completes when the user taps OK. Callers can
/// `await` it but normally don't need to.
Future<void> showAppErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'Got it',
  IconData icon = LucideIcons.triangleAlert,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _ErrorDialog(
      title: title,
      message: message,
      okLabel: okLabel,
      icon: icon,
    ),
  );
}

class _ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String okLabel;
  final IconData icon;
  const _ErrorDialog({
    required this.title,
    required this.message,
    required this.okLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: t.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
      child: Stack(
        children: [
          // Bold ember stripe along the top edge. The single strongest
          // brand signal for "stop and read this".
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(R.md),
                  topRight: Radius.circular(R.md),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg + 6, Sp.lg, Sp.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Big icon badge so the dialog reads as "alert" before
                // the user even parses the headline.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(R.s),
                    border: Border.all(color: t.accent, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: t.accent, size: 28),
                ),
                const SizedBox(height: Sp.md),
                Text(
                  title,
                  style: AppText.headline.copyWith(
                    color: t.ink,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: Sp.s),
                Text(
                  message,
                  style: AppText.body.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: Sp.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: Text(okLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.accentInk,
                      padding: const EdgeInsets.symmetric(vertical: Sp.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(R.s),
                      ),
                      textStyle: AppText.bodyStrong.copyWith(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

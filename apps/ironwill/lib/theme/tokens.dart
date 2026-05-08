import 'package:flutter/material.dart';

/// Semantic design tokens for LockedIn. All colours, spacing, radii, and
/// utilization data colours flow through this single extension. Feature code
/// must read these via `Theme.of(context).extension<AppTokens>()` and never
/// hardcode hex values, font names, or magic paddings.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunk;
  final Color divider;
  final Color ink;
  final Color inkMuted;
  final Color steel;
  final Color accent;
  final Color accentInk;

  // Utilization data ramp. Identical in light and dark themes.
  final Color uNotFocus;
  final Color uWasted;
  final Color uLow;
  final Color uMid;
  final Color uGood;
  final Color uFull;

  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunk,
    required this.divider,
    required this.ink,
    required this.inkMuted,
    required this.steel,
    required this.accent,
    required this.accentInk,
    required this.uNotFocus,
    required this.uWasted,
    required this.uLow,
    required this.uMid,
    required this.uGood,
    required this.uFull,
  });

  static const AppTokens light = AppTokens(
    bg: Color(0xFFF2EFE9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEAE6DF),
    surfaceSunk: Color(0xFFE3DED5),
    divider: Color(0xFFD8D3CA),
    ink: Color(0xFF0A0A0B),
    inkMuted: Color(0xFF4F4D4A),
    steel: Color(0xFF475569),
    accent: Color(0xFFEA580C),
    accentInk: Color(0xFFFFFFFF),
    uNotFocus: Color(0xFF2563EB),
    uWasted: Color(0xFFDC2626),
    uLow: Color(0xFFF97316),
    uMid: Color(0xFFEAB308),
    uGood: Color(0xFF84CC16),
    uFull: Color(0xFF16A34A),
  );

  static const AppTokens dark = AppTokens(
    bg: Color(0xFF07070A),
    surface: Color(0xFF111114),
    surfaceAlt: Color(0xFF18181C),
    surfaceSunk: Color(0xFF050507),
    divider: Color(0xFF25252B),
    ink: Color(0xFFECE9E2),
    inkMuted: Color(0xFF8B887F),
    steel: Color(0xFF94A3B8),
    accent: Color(0xFFF97316),
    accentInk: Color(0xFF07070A),
    uNotFocus: Color(0xFF2563EB),
    uWasted: Color(0xFFDC2626),
    uLow: Color(0xFFF97316),
    uMid: Color(0xFFEAB308),
    uGood: Color(0xFF84CC16),
    uFull: Color(0xFF16A34A),
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunk,
    Color? divider,
    Color? ink,
    Color? inkMuted,
    Color? steel,
    Color? accent,
    Color? accentInk,
    Color? uNotFocus,
    Color? uWasted,
    Color? uLow,
    Color? uMid,
    Color? uGood,
    Color? uFull,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunk: surfaceSunk ?? this.surfaceSunk,
      divider: divider ?? this.divider,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      steel: steel ?? this.steel,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      uNotFocus: uNotFocus ?? this.uNotFocus,
      uWasted: uWasted ?? this.uWasted,
      uLow: uLow ?? this.uLow,
      uMid: uMid ?? this.uMid,
      uGood: uGood ?? this.uGood,
      uFull: uFull ?? this.uFull,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSunk: Color.lerp(surfaceSunk, other.surfaceSunk, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      steel: Color.lerp(steel, other.steel, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      uNotFocus: Color.lerp(uNotFocus, other.uNotFocus, t)!,
      uWasted: Color.lerp(uWasted, other.uWasted, t)!,
      uLow: Color.lerp(uLow, other.uLow, t)!,
      uMid: Color.lerp(uMid, other.uMid, t)!,
      uGood: Color.lerp(uGood, other.uGood, t)!,
      uFull: Color.lerp(uFull, other.uFull, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

/// 4dp spacing scale.
class Sp {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double x3l = 40;
  static const double x4l = 48;
  static const double x5l = 64;
}

/// Sharpened radii. Cards are nearly square edged. The pill is reserved for
/// streak counters and segmented controls only.
class R {
  static const double xs = 2;
  static const double s = 4;
  static const double m = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 14;
  static const double pill = 999;
}

class IconSize {
  static const double s = 16;
  static const double m = 18;
  static const double l = 20;
  static const double xl = 28;
}

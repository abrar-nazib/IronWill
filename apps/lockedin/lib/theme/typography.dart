import 'package:flutter/material.dart';

/// LockedIn type ramp.
///
/// * Display + headline use **Hanken Grotesk**: sharper geometric grotesk,
///   strong stems, tighter joins than Inter. The masculine, editorial register.
/// * Body uses **Inter**: still the most legible body face on small screens.
/// * Numbers use **JetBrains Mono**: tabular, mechanical, makes streak counts
///   and minute totals feel earned.
/// * Section labels use **Hanken Grotesk** at small caps with wide tracking,
///   to lean editorial without going decorative.
///
/// All three families are bundled as variable TTFs in `assets/fonts/` so
/// the app needs no network at first run. The earlier `google_fonts`
/// integration fetched fonts from `fonts.gstatic.com` lazily and crashed
/// the release build on offline devices.
class AppText {
  static const String _hankenFamily = 'HankenGrotesk';
  static const String _interFamily = 'Inter';
  static const String _monoFamily = 'JetBrainsMono';

  static TextStyle _hanken(double size, FontWeight weight,
      {double letterSpacing = -0.4, double height = 1.05}) {
    return TextStyle(
      fontFamily: _hankenFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle _inter(double size, FontWeight weight,
      {double letterSpacing = -0.05, double height = 1.4}) {
    return TextStyle(
      fontFamily: _interFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle _mono(double size, FontWeight weight,
      {double letterSpacing = -0.3, double height = 1.0}) {
    return TextStyle(
      fontFamily: _monoFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Heroic numbers (focus minutes, streak count). Mono so digits stack.
  static TextStyle big = _mono(56, FontWeight.w700, letterSpacing: -2);

  /// Big stat number on a card.
  static TextStyle display = _mono(36, FontWeight.w700, letterSpacing: -1.2);

  /// Mid stat or page title number.
  static TextStyle displaySm = _mono(24, FontWeight.w700, letterSpacing: -0.8);

  /// Screen title.
  static TextStyle headline = _hanken(26, FontWeight.w700, letterSpacing: -0.6);

  /// Card title.
  static TextStyle title = _hanken(17, FontWeight.w700, letterSpacing: -0.2, height: 1.2);

  /// Body copy and form values.
  static TextStyle body = _inter(14.5, FontWeight.w400);

  /// Strong body for buttons and primary list rows.
  static TextStyle bodyStrong = _inter(14.5, FontWeight.w600);

  /// Captions, metric subtitles.
  static TextStyle label = _inter(12.5, FontWeight.w500);

  /// Section heading shown in tracked uppercase. Always pair with
  /// `letterSpacing` of about 1.6 and uppercase content.
  static TextStyle section = _hanken(11, FontWeight.w700, letterSpacing: 1.6, height: 1);

  /// Tabular figure run (clock, axis labels).
  static TextStyle mono = _mono(13, FontWeight.w500, letterSpacing: 0);

  /// Nav label.
  static TextStyle nav = _inter(11, FontWeight.w600);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildTheme({required Brightness brightness}) {
  final tokens = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;

  final color = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: tokens.accentInk,
    secondary: tokens.steel,
    onSecondary: tokens.bg,
    surface: tokens.surface,
    onSurface: tokens.ink,
    surfaceContainerHighest: tokens.surfaceAlt,
    surfaceContainerHigh: tokens.surfaceAlt,
    surfaceContainer: tokens.surface,
    surfaceContainerLow: tokens.bg,
    surfaceContainerLowest: tokens.bg,
    outline: tokens.divider,
    outlineVariant: tokens.divider,
    error: tokens.uWasted,
    onError: Colors.white,
    inversePrimary: tokens.accent,
    inverseSurface: tokens.ink,
    onInverseSurface: tokens.bg,
    onSurfaceVariant: tokens.inkMuted,
    scrim: Colors.black54,
    shadow: Colors.black12,
    tertiary: tokens.uFull,
    onTertiary: Colors.white,
  );

  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();

  return base.copyWith(
    extensions: [tokens],
    colorScheme: color,
    scaffoldBackgroundColor: tokens.bg,
    canvasColor: tokens.bg,
    dividerColor: tokens.divider,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.bg,
      surfaceTintColor: tokens.bg,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleTextStyle: AppText.headline.copyWith(color: tokens.ink),
      iconTheme: IconThemeData(color: tokens.ink, size: IconSize.l),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: tokens.surface,
      selectedItemColor: tokens.ink,
      unselectedItemColor: tokens.inkMuted,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: AppText.nav.copyWith(color: tokens.ink),
      unselectedLabelStyle: AppText.nav.copyWith(color: tokens.inkMuted),
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      surfaceTintColor: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.surfaceAlt,
      selectedColor: tokens.ink,
      disabledColor: tokens.surfaceAlt,
      labelStyle: AppText.label.copyWith(color: tokens.ink),
      secondaryLabelStyle: AppText.label.copyWith(color: tokens.bg),
      side: BorderSide(color: tokens.divider, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
      padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
    ),
    iconTheme: IconThemeData(color: tokens.ink, size: IconSize.l),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.accent,
      foregroundColor: tokens.accentInk,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: AppText.bodyStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.accentInk,
        elevation: 0,
        minimumSize: const Size(0, 48),
        textStyle: AppText.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.ink,
        minimumSize: const Size(0, 44),
        textStyle: AppText.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink,
        side: BorderSide(color: tokens.divider),
        minimumSize: const Size(0, 48),
        textStyle: AppText.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.ink,
      contentTextStyle: AppText.bodyStrong.copyWith(color: tokens.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.s)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: tokens.surface,
      modalBackgroundColor: tokens.surface,
      modalBarrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.s),
        borderSide: BorderSide(color: tokens.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.s),
        borderSide: BorderSide(color: tokens.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.s),
        borderSide: BorderSide(color: tokens.ink, width: 1.5),
      ),
      hintStyle: AppText.body.copyWith(color: tokens.inkMuted),
      labelStyle: AppText.label.copyWith(color: tokens.inkMuted),
    ),
    dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1, space: 1),
    textTheme: TextTheme(
      displayLarge: AppText.big.copyWith(color: tokens.ink),
      displayMedium: AppText.display.copyWith(color: tokens.ink),
      displaySmall: AppText.displaySm.copyWith(color: tokens.ink),
      headlineLarge: AppText.headline.copyWith(color: tokens.ink),
      headlineMedium: AppText.headline.copyWith(color: tokens.ink),
      titleLarge: AppText.title.copyWith(color: tokens.ink),
      titleMedium: AppText.title.copyWith(color: tokens.ink),
      bodyLarge: AppText.body.copyWith(color: tokens.ink),
      bodyMedium: AppText.body.copyWith(color: tokens.inkMuted),
      labelLarge: AppText.label.copyWith(color: tokens.ink),
      labelMedium: AppText.label.copyWith(color: tokens.inkMuted),
      labelSmall: AppText.section.copyWith(color: tokens.inkMuted),
    ),
  );
}

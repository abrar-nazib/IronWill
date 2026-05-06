import 'package:flutter/material.dart';

import 'models/models.dart';

class AppThemeController extends InheritedWidget {
  final ThemeMode mode;
  final void Function(ThemeMode) setMode;

  const AppThemeController({
    super.key,
    required this.mode,
    required this.setMode,
    required super.child,
  });

  static AppThemeController of(BuildContext context) {
    final c = context.dependOnInheritedWidgetOfExactType<AppThemeController>();
    assert(c != null, 'AppThemeController missing in widget tree');
    return c!;
  }

  @override
  bool updateShouldNotify(AppThemeController old) => old.mode != mode;
}

ThemeMode themeChoiceToMode(ThemeChoice c) => switch (c) {
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
      ThemeChoice.system => ThemeMode.system,
    };

ThemeChoice themeModeToChoice(ThemeMode m) => switch (m) {
      ThemeMode.light => ThemeChoice.light,
      ThemeMode.dark => ThemeChoice.dark,
      ThemeMode.system => ThemeChoice.system,
    };

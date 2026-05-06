import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Six discrete utilization states for both 15 minute time blocks and habit
/// daily cells. The semantic intent is the same in both surfaces: how much of
/// the planned focus or habit was actually accomplished. `notFocus` is for
/// blocks deliberately reserved for sleep, family, or scheduled non focus time.
enum Utilization {
  none,
  notFocus,
  wasted,
  low,
  mid,
  good,
  full,
}

extension UtilizationX on Utilization {
  /// Numeric percent. `none` and `notFocus` are not on the percent ramp; they
  /// return null so callers can decide how to render them.
  int? get percent => switch (this) {
        Utilization.none => null,
        Utilization.notFocus => null,
        Utilization.wasted => 0,
        Utilization.low => 25,
        Utilization.mid => 50,
        Utilization.good => 75,
        Utilization.full => 100,
      };

  /// Generic label, used for the legend in mixed contexts.
  String get label => switch (this) {
        Utilization.none => 'Unlogged',
        Utilization.notFocus => 'Not focus',
        Utilization.wasted => 'Wasted',
        Utilization.low => 'Distracted',
        Utilization.mid => 'Half',
        Utilization.good => 'Mostly focused',
        Utilization.full => 'Fully focused',
      };

  /// Habit-flavoured label. Used in the habit log sheet and habit calendar
  /// legend. The 5-step ramp reads: Done, Mostly, Half, Barely, Missed.
  String get habitLabel => switch (this) {
        Utilization.none => 'Unlogged',
        Utilization.notFocus => 'Skip day',
        Utilization.wasted => 'Missed',
        Utilization.low => 'Barely',
        Utilization.mid => 'Half',
        Utilization.good => 'Mostly',
        Utilization.full => 'Done',
      };

  /// Time-tracker label. Used in the quarter log sheet and time grid legend.
  String get focusLabel => label;

  Color color(AppTokens t) => switch (this) {
        Utilization.none => Colors.transparent,
        Utilization.notFocus => t.uNotFocus,
        Utilization.wasted => t.uWasted,
        Utilization.low => t.uLow,
        Utilization.mid => t.uMid,
        Utilization.good => t.uGood,
        Utilization.full => t.uFull,
      };
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories.dart';
import 'features/habits/habit_detail_screen.dart';
import 'features/habits/habits_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/sessions/recurring_planner_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/sub_screens.dart';
import 'features/shell/shell.dart';
import 'features/stats/stats_screen.dart';
import 'features/stats/subject_detail_screen.dart';
import 'features/tracker/tracker_screen.dart';
import 'models/models.dart';
import 'services/app_services.dart';

GoRouter buildRouter(AppServices services) {
  return GoRouter(
    initialLocation: '/today',
    navigatorKey: _rootKey,
    refreshListenable: _Listenable(services.settings.settings),
    redirect: (context, state) {
      final s = services.settings.settings.value;
      final goingTo = state.matchedLocation;
      if (!s.onboarded && goingTo != '/onboarding') return '/onboarding';
      if (s.onboarded && goingTo == '/onboarding') return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootKey,
        builder: (c, s) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/today',
            pageBuilder: (c, s) => const NoTransitionPage(child: _Wrap(child: HomeScreen())),
          ),
          GoRoute(
            path: '/time',
            pageBuilder: (c, s) => const NoTransitionPage(child: TrackerScreen()),
          ),
          GoRoute(
            path: '/habits',
            pageBuilder: (c, s) => const NoTransitionPage(child: HabitsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootKey,
                builder: (c, s) => HabitDetailScreen(habitId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/stats',
            pageBuilder: (c, s) => const NoTransitionPage(child: StatsScreen()),
            routes: [
              GoRoute(
                path: 'subject/:id',
                parentNavigatorKey: _rootKey,
                builder: (c, s) {
                  final rangeName = s.uri.queryParameters['range'] ?? 'week';
                  final range = StatsRange.values.firstWhere(
                    (r) => r.name == rangeName,
                    orElse: () => StatsRange.week,
                  );
                  return SubjectDetailScreen(
                    subjectId: s.pathParameters['id']!,
                    initialRange: range,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (c, s) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'focus-minimum',
            builder: (c, s) => const FocusMinimumScreen(),
          ),
          GoRoute(
            path: 'alarm',
            builder: (c, s) => const AlarmSoundScreen(),
          ),
          GoRoute(
            path: 'first-day',
            builder: (c, s) => const FirstDayScreen(),
          ),
          GoRoute(
            path: 'archived',
            builder: (c, s) => const ArchivedScreen(),
          ),
          GoRoute(
            path: 'privacy-lock',
            builder: (c, s) => const PrivacyLockScreen(),
          ),
          GoRoute(
            path: 'subjects',
            builder: (c, s) => const SubjectsScreen(),
          ),
          GoRoute(
            path: 'sessions',
            builder: (c, s) => const SessionsScreen(),
            routes: [
              GoRoute(
                path: 'plan',
                builder: (c, s) => const RecurringPlannerScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'pomodoro',
            builder: (c, s) => const PomodoroSettingsScreen(),
          ),
          GoRoute(
            path: 'block-size',
            builder: (c, s) => const BlockSizeScreen(),
          ),
        ],
      ),
    ],
  );
}

final _rootKey = GlobalKey<NavigatorState>();

class _Wrap extends StatelessWidget {
  final Widget child;
  const _Wrap({required this.child});
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: child);
}

/// Bridges a ValueListenable to the [Listenable] go_router expects on
/// `refreshListenable`.
class _Listenable extends ChangeNotifier {
  _Listenable(ValueListenable<AppSettings> source) {
    source.addListener(notifyListeners);
  }
}

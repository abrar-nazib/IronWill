import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../models/utilization.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/active_session_timer.dart';
import '../../widgets/quarter_grid.dart';
import '../../widgets/utilization_legend.dart';
import 'log_block_sheet.dart';
import 'quarter_logger.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  /// Cached copy of `AppServices.trackerDate` so we have a snapshot to
  /// reason about during async log calls. The notifier is the source of
  /// truth; we mirror its value here and listen for external changes.
  late DateTime _date;
  late Future<DayBlocks> _dayFuture;
  bool _consumedLogIntent = false;

  /// Captured at first didChangeDependencies so dispose() can remove
  /// the listener without calling AppServices.of(context) (which would
  /// throw in dispose because the widget is no longer in the tree).
  ValueNotifier<DateTime>? _dateNotifier;
  VoidCallback? _dateListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = AppServices.of(context);
    // Honour whatever date the user last navigated to via the chevrons
    // (the notifier survives tab switches). Never auto-snap to today
    // from here: opening the log bottom sheet triggers another
    // didChangeDependencies tick, and that flipped trackerDate out
    // from under in-flight log writes, sending past-day taps into
    // today by accident. The user-facing reset is the "BACK TO TODAY"
    // pill in the AppBar.
    _date = svc.trackerDate.value;
    _dayFuture = svc.time.getDay(_date);
    if (_dateNotifier == null) {
      _dateNotifier = svc.trackerDate;
      _dateListener = () {
        if (!mounted) return;
        final next = _dateNotifier!.value;
        if (next != _date) {
          setState(() {
            _date = next;
            _dayFuture = svc.time.getDay(next);
          });
        }
      };
      _dateNotifier!.addListener(_dateListener!);
    }
    _maybeConsumeLogIntent();
  }

  @override
  void dispose() {
    if (_dateNotifier != null && _dateListener != null) {
      _dateNotifier!.removeListener(_dateListener!);
    }
    super.dispose();
  }

  /// If the screen was navigated to with `?log=now` (from a 15-min tick
  /// notification, a foreground-service tap, or the floating-window button),
  /// open the smart quarter picker then the log sheet exactly once and clean
  /// the URL afterwards. The flag resets the moment the URL no longer carries
  /// `log=now`, so subsequent triggers on this same screen instance work too.
  ///
  /// Notification-driven logs always target today, even if the user had
  /// the tracker stuck on an older day: a session-tick fires for the
  /// session that's running right now, and writing it into a viewed
  /// past day would be wrong. So we snap to today before running the
  /// picker, then restore the previous date afterwards.
  void _maybeConsumeLogIntent() {
    final state = GoRouterState.of(context);
    final wantLog = state.uri.queryParameters['log'] == 'now';
    if (!wantLog) {
      _consumedLogIntent = false;
      return;
    }
    if (_consumedLogIntent) return;
    _consumedLogIntent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final svc = AppServices.of(context);
      final previousDate = svc.trackerDate.value;
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      if (previousDate != todayDate) {
        svc.trackerDate.value = todayDate;
      }
      final size = svc.settings.settings.value.blockSizeMinutes;
      final picked = await SmartQuarterPicker(blockSizeMinutes: size).pick(context);
      if (!mounted) return;
      if (picked != null) {
        final day = await _dayFuture;
        if (!mounted) return;
        await _logQuarter(day, picked);
      }
      if (!mounted) return;
      context.go('/time');
    });
  }

  void _setDate(DateTime d) {
    final svc = AppServices.of(context);
    svc.trackerDate.value = d;
    setState(() {
      _date = d;
      _dayFuture = svc.time.getDay(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<DayBlocks>(
          future: _dayFuture,
          builder: (context, snap) {
            final day = snap.data;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: t.bg,
                  surfaceTintColor: t.bg,
                  toolbarHeight: 76,
                  title: Padding(
                    padding: const EdgeInsets.only(top: Sp.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (_) {
                            final now = DateTime.now();
                            final todayDate = DateTime(now.year, now.month, now.day);
                            final isToday = _date == todayDate;
                            return Row(
                              children: [
                                Text(
                                  isToday ? 'TODAY' : 'VIEWING',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: isToday ? t.inkMuted : t.accent,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                      ),
                                ),
                                if (!isToday) ...[
                                  const SizedBox(width: Sp.s),
                                  InkWell(
                                    onTap: () => _setDate(todayDate),
                                    borderRadius: BorderRadius.circular(R.pill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: Sp.s, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: t.accent,
                                        borderRadius:
                                            BorderRadius.circular(R.pill),
                                      ),
                                      child: Text(
                                        'BACK TO TODAY',
                                        style: AppText.label.copyWith(
                                          color: t.accentInk,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: Sp.xs),
                        Text(
                          DateFormat('EEEE, d MMM').format(_date),
                          style: AppText.headline.copyWith(color: t.ink),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft),
                      tooltip: 'Previous day',
                      onPressed: () => _setDate(_date.subtract(const Duration(days: 1))),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.chevronRight),
                      tooltip: 'Next day',
                      onPressed: () => _setDate(_date.add(const Duration(days: 1))),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.settings),
                      tooltip: 'Settings',
                      onPressed: () => context.push('/settings'),
                    ),
                    const SizedBox(width: Sp.s),
                  ],
                ),
                if (day == null)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Sp.x4l),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.x4l),
                    sliver: SliverList.list(children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: Sp.m),
                        child: ActiveSessionTimer(),
                      ),
                      _TopMetrics(day: day),
                      const SizedBox(height: Sp.m),
                      AppCard(
                        padding: const EdgeInsets.all(Sp.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader('Legend'),
                            const UtilizationLegend(),
                          ],
                        ),
                      ),
                      const SizedBox(height: Sp.m),
                      _GridCard(day: day, onTap: (i) => _logQuarter(day, i)),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder<AppSettings>(
        valueListenable: AppServices.of(context).settings.settings,
        builder: (_, settings, __) {
          final size = settings.blockSizeMinutes;
          final label = size == 60
              ? 'Log this hour'
              : (size == 30 ? 'Log this 30 min' : 'Log this 15 min');
          return FloatingActionButton.extended(
            icon: const Icon(LucideIcons.bellRing),
            label: Text(label),
            onPressed: () async {
              final picked = await SmartQuarterPicker(blockSizeMinutes: size)
                  .pick(context);
              if (picked == null || !mounted) return;
              final day = await _dayFuture;
              if (!mounted) return;
              await _logQuarter(day, picked);
            },
          );
        },
      ),
    );
  }

  /// [firstIndex] is the FIRST 15-minute quarter inside the tapped block.
  /// When the user is on 30 or 60 min view, the same chosen utilization is
  /// written to all sub-quarters in that block so the storage stays
  /// consistent and switching views back to 15 min preserves the data.
  Future<void> _logQuarter(DayBlocks day, int firstIndex) async {
    final svc = AppServices.of(context);
    final blockSize = svc.settings.settings.value.blockSizeMinutes;
    final stride = blockSize == 60 ? 4 : (blockSize == 30 ? 2 : 1);
    final aggregated = aggregateQuartersInBlock(
      quarters: day.quarters,
      firstQuarterIndex: firstIndex,
      stride: stride,
    );
    // Subject inference: any focus session that overlaps the block's
    // wall-clock window contributes a candidate subject. If exactly one
    // session matches, we surface it for the inference fallback. If
    // multiple match, we surface them all and flag "askWhich".
    final blockStart = DateTime(
        _date.year, _date.month, _date.day, 0, 0, 0)
        .add(Duration(minutes: firstIndex * 15));
    final blockEnd = blockStart.add(Duration(minutes: blockSize));
    final overlapping = svc.focusSessions.overlapping(blockStart, blockEnd);
    final subjectsAll = svc.subjects.all.value;
    final subjectsById = {for (final s in subjectsAll) s.id: s};
    final candidates = <Subject>[];
    final seen = <String>{};
    var distinctSubjects = 0;
    for (final s in overlapping) {
      if (s.subjectId == null) continue;
      if (seen.add(s.subjectId!)) {
        final subj = subjectsById[s.subjectId];
        if (subj != null) {
          candidates.add(subj);
          distinctSubjects++;
        }
      }
    }
    if (candidates.isEmpty) candidates.addAll(subjectsAll);
    final askWhich = distinctSubjects > 1;

    // Resolve default subject precedence:
    //   1. Last picked in this session (including explicit "No subject")
    //      so repeat-logging stays sticky for the user.
    //   2. The block's existing subject_id (only when this block was
    //      already logged once).
    //   3. The subject of a single overlapping focus session.
    //   4. Otherwise null ("No subject" chip pre-selected).
    String? defaultSubject;
    final lastPicked = svc.lastPickedLogSubject.value;
    final wasLoggedBefore = firstIndex < day.quarters.length &&
        day.quarters[firstIndex] != Utilization.none;
    if (lastPicked.isSet) {
      defaultSubject = lastPicked.subjectId;
    } else if (wasLoggedBefore &&
        day.subjectIds.length == day.quarters.length &&
        firstIndex < day.subjectIds.length) {
      defaultSubject = day.subjectIds[firstIndex];
    } else if (distinctSubjects == 1) {
      defaultSubject = candidates.first.id;
    }

    final picked = await showLogBlockSheet(
      context,
      current: aggregated,
      quarterIndex: firstIndex,
      blockSizeMinutes: blockSize,
      candidateSubjects: candidates,
      defaultSubjectId: defaultSubject,
      askWhichSession: askWhich,
    );
    if (picked == null) return;
    for (var i = 0; i < stride; i++) {
      final idx = firstIndex + i;
      if (idx >= 96) break;
      await svc.time.logQuarter(
        _date,
        idx,
        picked.utilization,
        subjectId: picked.subjectId,
        clearSubjectId: picked.clearSubjectId,
      );
    }
    // Remember this pick so the next "Log this block" tap defaults to
    // the same subject (or explicitly to "No subject" if that was the
    // user's choice).
    svc.lastPickedLogSubject.value = LastPickedLog.value(picked.subjectId);
    if (!mounted) return;
    setState(() {
      _dayFuture = svc.time.getDay(_date);
    });
  }
}

class _TopMetrics extends StatelessWidget {
  final DayBlocks day;
  const _TopMetrics({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final focusMin = day.focusedMinutes;
    final pct = (day.utilizationPercent * 100).round();
    return Row(
      children: [
        Expanded(
          child: AppCard(
            color: t.ink,
            stroked: false,
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FOCUSED', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.bg.withValues(alpha: 0.6))),
                const SizedBox(height: Sp.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$focusMin', style: AppText.display.copyWith(color: t.bg)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('min', style: AppText.label.copyWith(color: t.bg.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: Sp.m),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UTILIZATION', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                const SizedBox(height: Sp.s),
                Text('$pct%', style: AppText.display.copyWith(color: t.ink)),
                const SizedBox(height: 4),
                Text('${day.loggedQuarterCount} of 96 quarters logged',
                    style: AppText.label.copyWith(color: t.inkMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final DayBlocks day;
  final void Function(int) onTap;
  const _GridCard({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final svc = AppServices.of(context);
    return ValueListenableBuilder<AppSettings>(
      valueListenable: svc.settings.settings,
      builder: (_, settings, __) {
        final size = settings.blockSizeMinutes;
        return AppCard(
          padding: const EdgeInsets.all(Sp.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('24 hour grid'),
              const SizedBox(height: Sp.s),
              QuarterGrid(
                quarters: day.quarters,
                blockSizeMinutes: size,
                onTap: onTap,
              ),
            ],
          ),
        );
      },
    );
  }
}

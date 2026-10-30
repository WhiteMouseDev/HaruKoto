import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable instant source; study calendar dates always use Korea time.
final studyClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

DateTime studyDateInKorea(DateTime instant) {
  final koreaTime = instant.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(koreaTime.year, koreaTime.month, koreaTime.day);
}

String studyDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final studyDateProvider =
    NotifierProvider.autoDispose<StudyDateNotifier, DateTime>(
  StudyDateNotifier.new,
);

class StudyDateNotifier extends Notifier<DateTime> {
  Timer? _midnightTimer;

  @override
  DateTime build() {
    final now = ref.watch(studyClockProvider)();
    ref.onDispose(() => _midnightTimer?.cancel());
    _scheduleMidnight(now);
    return studyDateInKorea(now);
  }

  /// Also called on resume, since background timers can be suspended.
  void refresh() {
    final now = ref.read(studyClockProvider)();
    final date = studyDateInKorea(now);
    if (state != date) state = date;
    _scheduleMidnight(now);
  }

  void _scheduleMidnight(DateTime now) {
    _midnightTimer?.cancel();
    final nextMidnight = studyDateInKorea(now)
        .add(const Duration(days: 1))
        .subtract(const Duration(hours: 9));
    _midnightTimer = Timer(nextMidnight.difference(now.toUtc()), refresh);
  }
}

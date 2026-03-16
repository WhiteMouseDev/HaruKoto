import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _random = Random();
  static bool _initialized = false;

  // Notification IDs
  static const _reminderNotificationId = 1;
  static const _streakNotificationId = 2;

  // --- 리마인더 문구 풀 ---
  static const _reminderMessages = [
    '오늘의 일본어, 준비됐어요!',
    '3분이면 충분해요. 오늘도 한 걸음!',
    '어제 배운 단어, 아직 기억나요?',
    '오늘의 퀴즈가 기다리고 있어요!',
    '매일 조금씩, 실력은 쑥쑥!',
    '일본어 한 마디, 오늘도 시작해볼까요?',
    '오늘의 단어를 만나러 가볼까요?',
    '꾸준함이 실력이에요. 오늘도 화이팅!',
  ];

  // --- 스트릭 방어 문구 풀 ---
  static const _streakMessages = [
    '오늘 학습을 아직 안 했어요! 스트릭이 끊기기 전에 한 문제라도!',
    '자정까지 2시간 남았어요. 스트릭을 지켜주세요!',
    '한 문제만 풀면 스트릭 유지! 지금 바로 도전!',
    '여기서 끊기면 너무 아깝지 않아요?',
    '오늘의 학습, 아직 늦지 않았어요!',
    '스트릭을 이어가는 건 오늘의 나에게 달려 있어요!',
  ];

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Schedule daily study reminder at user-selected time
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _plugin.cancel(_reminderNotificationId);

    final message =
        _reminderMessages[_random.nextInt(_reminderMessages.length)];

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      '하루코토',
      message,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_reminder',
          '학습 리마인더',
          channelDescription: '매일 설정한 시간에 학습 리마인더를 보냅니다',
          importance: Importance.high,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule streak defense notification at 22:00 daily
  static Future<void> scheduleStreakDefense() async {
    await _plugin.cancel(_streakNotificationId);

    final message = _streakMessages[_random.nextInt(_streakMessages.length)];

    await _plugin.zonedSchedule(
      _streakNotificationId,
      '하루코토',
      message,
      _nextInstanceOfTime(22, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_defense',
          '스트릭 방어',
          channelDescription: '스트릭이 끊기기 전에 알림을 보냅니다',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel streak defense for today (called when user completes study)
  static Future<void> cancelStreakDefenseToday() async {
    await _plugin.cancel(_streakNotificationId);
    // Re-schedule for tomorrow (with new random message)
    await scheduleStreakDefense();
  }

  /// Cancel daily reminder
  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Cancel streak defense
  static Future<void> cancelStreakDefense() async {
    await _plugin.cancel(_streakNotificationId);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

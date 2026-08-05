import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nitya_sadhana/models/panchang_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _baseBrahmaId = 100;
  static const _baseSandhyaId = 107;
  static const _scheduleDays = 7;
  static const _prefLastScheduled = 'notif_last_scheduled';
  static const _prefLastTzOffSet = 'notif_last_tz_offset';

  // Sound options: 'default' uses system alarm, others map to raw resource files
  // Place custom .mp3 files in android/app/src/main/res/raw/ (without extension)
  // and ios Runner/ (add to Xcode project)
  static const soundOptions = {
    'default': 'Default Alarm',
    'fault': 'Fault',
    'temple_bell': 'Temple Bell',
    'om_chant': 'Om Chant',
  };

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  // Rolling 7-day schedule

  /// Schedule Brahma Muhurta and/or Sandhya kaal for the next 7 days.
  /// Call this on every app open (after panchang loads) and after any
  /// toggle/sound change. Cancels stale notifications before re-scheduling
  static Future<void> scheduleWeek({
    required List<PanchangData> days,
    required bool brahmaMuhurta,
    required bool sandhyaKaal,
    String sound = 'default',
  }) async {
    // Cancel all existing muhurta notification first
    await _cancelAllMuhurta();

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < days.length && i < _scheduleDays; i++) {
      final day = days[i];

      // Brahma Muhurta (96 min before sunrise)
      if (brahmaMuhurta && day.sunriseDateTime != null) {
        final bm = day.sunriseDateTime!.subtract(
          const Duration(hours: 1, minutes: 36),
        );
        final scheduleTime = tz.TZDateTime.from(bm, tz.local);
        if (scheduleTime.isAfter(now)) {
          await _schedule(
            id: _baseBrahmaId + i,
            title: '🙏 Brahma Muhurta',
            body:
                'The most auspicious time for japa begins now, Start your sadhana.',
            scheduledDate: scheduleTime,
            channelId: 'brahma_muhurta',
            channelName: 'Brahma Muhurta',
            channelDesc: 'Daily reminder for Brahma Muhurta japa time',
            sound: sound,
          );
        }
      }

      // Sandhya Kaal (at sunset)
      if (sandhyaKaal && day.sunriseDateTime != null) {
        final scheduleTime = tz.TZDateTime.from(day.sunriseDateTime!, tz.local);
        if (scheduleTime.isAfter(now)) {
          await _schedule(
            id: _baseSandhyaId + i,
            title: '🙏 Sandhya kaal',
            body:
                'Twilight hour - an auspicious time for evening prayers and japa',
            scheduledDate: scheduleTime,
            channelId: 'sandhya_kaal',
            channelName: 'Sandhya Kaal',
            channelDesc: 'Daily reminder for Sandhya Kaal (sunset) japa',
            sound: sound,
          );
        }
      }
    }

    // Record last schedule date + timezone offset so we can detect changes
    final prefs = await SharedPreferences.getInstance();
    final scheduledAt = DateTime.now();
    await prefs.setString(_prefLastScheduled, scheduledAt.toIso8601String());
    await prefs.setInt(_prefLastTzOffSet, scheduledAt.timeZoneOffset.inMinutes);

    debugPrint(
      '[NotificationService] Scheduled ${brahmaMuhurta ? "Brahma Muhurta" : ""}${brahmaMuhurta && sandhyaKaal && sandhyaKaal ? " + " : ""}${sandhyaKaal ? "Sandhya Kaal" : ""} for ${days.length} days',
    );
  }

  /// Return true if notifications should be rescheduled.
  /// Triggers on: new day, timezone/DST change, or first-eve schedule.
  static Future<bool> needsRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_prefLastScheduled);
    if (lastStr == null) return true;
    final last = DateTime.tryParse(lastStr);
    if (last == null) return true;

    final now = DateTime.now();

    // New day since last schedule
    if (last.day != now.day || last.month != now.month || last.year != now.year) {
      return true;
    }

    // Timezone offset changed (DST transition or user travelled)
    final savedOffset = prefs.getInt(_prefLastTzOffSet);
    if (savedOffset != null && savedOffset != now.timeZoneOffset.inMinutes) {
      debugPrint(
        '[NotificationService] TZ offset changed: $savedOffset -> ${now.timeZoneOffset.inMinutes}',
      );
      return true;
    }

    return false;
  }

  // Single notification helpers (kept for backward compat)
  static Future<void> scheduleBrahmaMuhurta(
    DateTime sunriseLocal, {
    String sound = 'default',
  }) async {
    final bm = sunriseLocal.subtract(const Duration(hours: 1, minutes: 36));
    var scheduledTime = tz.TZDateTime.from(bm, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _schedule(
      id: _baseBrahmaId,
      title: '🙏 Brahma Muhurta',
      body: 'The most auspicious time for japa begins now, Start your sadhana.',
      scheduledDate: scheduledTime,
      channelId: 'brahma_muhurta',
      channelName: 'Brahma Muhurta',
      channelDesc: 'Daily reminder for Brahma Muhurta japa time',
      sound: sound,
    );
  }

  static Future<void> scheduleSandhyaKaal(
    DateTime sunsetLocal, {
    String sound = 'default',
  }) async {
    var scheduledTime = tz.TZDateTime.from(sunsetLocal, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _schedule(
      id: _baseSandhyaId,
      title: '🙏 Sandhta kaal',
      body: 'Twilight hour - an auspicuius time for evening prayers and japa',
      scheduledDate: scheduledTime,
      channelId: 'sandhya_kaal',
      channelName: 'Sandhya Kaal',
      channelDesc: 'Daily reminder for Sandhya Kaal (sunset) japa',
      sound: sound,
    );
  }

  // Cancel helper
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> cancelBrahmaMuhurta() async {
    for (int i = 0; i < _scheduleDays; i++) {
      await _plugin.cancel(id: _baseBrahmaId + i);
    }
  }

  static Future<void> cancelSandhyaKaal() async {
    for (int i = 0; i < _scheduleDays; i++) {
      await _plugin.cancel(id: _baseSandhyaId + i);
    }
  }

  static Future<void> _cancelAllMuhurta() async {
    for (int i = 0; i < _scheduleDays; i++) {
      await _plugin.cancel(id: _baseBrahmaId + i);
      await _plugin.cancel(id: _baseSandhyaId + i);
    }
  }

  // permission
  static Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Notification permission error; $e');
      return false;
    }
  }

  // Internal
  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String sound,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: _androidDetails(
          channelId: channelId,
          channelName: channelName,
          channelDesc: channelDesc,
          sound: sound,
        ),
        iOS: _iosDetails(sound),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String sound,
  }) {
    if (sound == 'default') {
      return AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
    }

    return AndroidNotificationDetails(
      '${channelId}_$sound',
      '$channelName ($sound)',
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sound),
    );
  }

  static DarwinNotificationDetails _iosDetails(String sound) {
    if (sound == 'default') return const DarwinNotificationDetails();
    return DarwinNotificationDetails(sound: '$sound.mp3');
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Sound options: 'default' uses system alarm, others map to raw resource files
  // Place custom .mp3 files in android/app/src/main/res/raw/ (without expression)
  // and ios Runner/ (and to Xcode project)
  static const soundOptions = {
    'default': 'Default Alarm',
    'fault': 'Fault',
    'temple_bell': 'Temple Bell',
    'om_chant': 'Om Chant',
  };

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(settings: const InitializationSettings(android: androidSettings, iOS: iosSettings));
    _initialized = true;
  }

  static AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String sound,
  }) {
    if (sound == 'default') {
      return AndroidNotificationDetails(
        channelId, channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true
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

  static Future<void> scheduleBrahmaMuhurta(DateTime sunriseLocal, {String sound = 'default'}) async {
    final brahmaMuhurta = sunriseLocal.subtract(const Duration(hours: 1, minutes: 36));
    var scheduledTime = tz.TZDateTime.from(brahmaMuhurta, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 100,
      title: 'Brahma Muhurta',
      body: 'The most auspicious time for japa begins now. Open the app and start your sadhana.',
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: _androidDetails(
          channelId: 'brahma_muhurta',
          channelName: 'Brahma Muhurta',
          channelDesc: 'Daily reminder for Brahma Muhurta japa time',
          sound: sound
        ),
        iOS: _iosDetails(sound),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleSandhyaKaal(DateTime sunsetLocal, {String sound = 'default'}) async {
    var scheduledTime = tz.TZDateTime.from(sunsetLocal, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 101,
      title: 'Sandhya Kaal',
      body: 'Twilight hour — an auspicious time for evening prayers and japa.',
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: _androidDetails(
          channelId: 'sandhya_kaal',
          channelName: 'Sandhya Kaal',
          channelDesc: 'Daily reminder for Sandhya Kaal (sunset) prayers',
          sound: sound
        ),
        iOS: _iosDetails(sound),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> cancelBrahmaMuhurta() async {
    await _plugin.cancel(id: 100);
  }

  static Future<void> cancelSandhyaKaal() async {
    await _plugin.cancel(id: 101);
  }

  static Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }
}

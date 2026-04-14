import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> scheduleBrahmaMuhurta(DateTime sunriseLocal) async {
    final brahmaMuhurta = sunriseLocal.subtract(const Duration(hours: 1, minutes: 36));
    if (brahmaMuhurta.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      100,
      'Brahma Muhurta',
      'The most auspicious time for japa begins now. Open the app and start your sadhana.',
      tz.TZDateTime.from(brahmaMuhurta, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'brahma_muhurta',
          'Brahma Muhurta',
          channelDescription: 'Daily reminder for Brahma Muhurta japa time',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleSandhyaKaal(DateTime sunsetLocal) async {
    if (sunsetLocal.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      101,
      'Sandhya Kaal',
      'Twilight hour — an auspicious time for evening prayers and japa.',
      tz.TZDateTime.from(sunsetLocal, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sandhya_kaal',
          'Sandhya Kaal',
          channelDescription: 'Daily reminder for Sandhya Kaal (sunset) prayers',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> cancelBrahmaMuhurta() async {
    await _plugin.cancel(100);
  }

  static Future<void> cancelSandhyaKaal() async {
    await _plugin.cancel(101);
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

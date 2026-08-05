
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nitya_sadhana/services/ad_service.dart';
import 'package:nitya_sadhana/services/auth_service.dart';
import 'package:nitya_sadhana/services/sadhana_mode_service.dart';
import 'package:nitya_sadhana/services/subscription_service.dart';

import 'app.dart';
import 'providers/japa_provider.dart';
import 'providers/panchang_provider.dart';
import 'providers/compass_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

final appInitializedProvider = FutureProvider<bool>((ref) {
  return Future.microtask(() async {
    await ref.read(subscriptionProvider).initialize();
    await ref.read(settingsProvider).initialize();
    await NotificationService.init();
    await ref.read(japaProvider).initialize();
    await ref.read(panchangProvider).initialize();
    ref.read(compassProvider).initialize();
    await ref.read(sadhanaModeProvider).initialize();
    await ref.read(authServiceProvider).initialize();
    await ref.read(adProviderService).initialize();

    // Auto-reschedule muhurta notifications if a new day has started
    _refreshMuhurtaNotifications(ref);

    return true;
  });
});

/// Reschedule Brahma Muhurta / Sandhya Kaal for the next 7 days
/// Called on every app launch after panchang + settings are ready.
/// Only re-schedule if the dats has changed since last schedule.
Future<void> _refreshMuhurtaNotifications(Ref ref) async {
  try {
    final needsRefresh = await NotificationService.needsRefresh();
    if(!needsRefresh) return;

    final settings = ref.read(settingsProvider);
    final sub = ref.read(subscriptionProvider);
    final panchang = ref.read(panchangProvider);

    // Premium-only feature
    if (!sub.isPremium) return;

    final hasBrahma = settings.brahmaMuhurtaNotif;
    final hasSandhya = settings.sandhyaKaalNotif;
    if (!hasBrahma && !hasSandhya) return;

    if (panchang.days.isEmpty) return;

    await NotificationService.scheduleWeek(
      days: panchang.days,
      brahmaMuhurta: hasBrahma,
      sandhyaKaal: hasSandhya,
      sound: settings.notifSound,
    );
  } catch (e) {
    debugPrint('[main] Failed to refresh muhurta notifications: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // App Check - auto-selects debug for dev, production attestation for release
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFFFF8F0),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(
    const ProviderScope(
      child: _AppLoader(),
    ),
  );
}

class _AppLoader extends ConsumerWidget {
  const _AppLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initAsync = ref.watch(appInitializedProvider);

    return initAsync.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFF8F0),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.spa_rounded,
                  size: 56,
                  color: Color(0xFFE8841A),
                ),
                SizedBox(height: 16),
                Text(
                  'Nitya Sadhana',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D1B0E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (err, stack) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFF8F0),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Something went wrong.\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6D4C41), fontSize: 14),
              ),
            ),
          ),
        ),
      ),
      data: (_) => const NityaSadhanaApp(),
    );
  }
}

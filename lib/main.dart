import 'dart:async';

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
import 'package:nitya_sadhana/utils/app_logger.dart';

import 'app.dart';
import 'providers/japa_provider.dart';
import 'providers/panchang_provider.dart';
import 'providers/compass_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

final appInitializedProvider = FutureProvider((ref) {
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
    await _refreshMuhurtaNotifications(ref);

    return true;
  });
});

/// Reschedule Brahma Muhurta / Sandhya Kaal for the next 7 days.
/// Called on every app launch after panchang + settings are ready.
Future<void> _refreshMuhurtaNotifications(Ref ref) async {
  try {
    AppLogger.info('[main] Checking muhurta notification refresh');

    final needsRefresh = await NotificationService.needsRefresh();

    if (!needsRefresh) {
      AppLogger.info('[main] Muhurta notifications do not need refresh');
      return;
    }

    final settings = ref.read(settingsProvider);
    final sub = ref.read(subscriptionProvider);
    final panchang = ref.read(panchangProvider);

    // Premium-only feature
    if (!sub.isPremium) {
      AppLogger.info('[main] User is not premium, skipping muhurta refresh');
      return;
    }

    final hasBrahma = settings.brahmaMuhurtaNotif;
    final hasSandhya = settings.sandhyaKaalNotif;

    if (!hasBrahma && !hasSandhya) {
      AppLogger.info('[main] No muhurta notifications enabled');
      return;
    }

    if (panchang.days.isEmpty) {
      AppLogger.warning('[main] Panchang days are empty');
      return;
    }

    await NotificationService.scheduleWeek(
      days: panchang.days,
      brahmaMuhurta: hasBrahma,
      sandhyaKaal: hasSandhya,
      sound: settings.notifSound,
    );

    AppLogger.info('[main] Muhurta notifications refreshed successfully');
  } catch (e, stackTrace) {
    AppLogger.error(
      '[main] Failed to refresh muhurta notifications',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize file logger first.
  await AppLogger.init();

  AppLogger.info('========== APP STARTING ==========');

  // Capture Flutter framework errors.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    AppLogger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Catch uncaught asynchronous errors.
  runZonedGuarded(
        () async {
      try {
        AppLogger.info('Initializing Firebase...');

        await Firebase.initializeApp();

        AppLogger.info('Firebase initialized successfully');

        // App Check - debug for development,
        // Play Integrity / DeviceCheck for release.
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        );

        AppLogger.info('Firebase App Check initialized');

        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);

        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFFFFF8F0),
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );

        AppLogger.info('System UI configured');

        runApp(
          const ProviderScope(
            child: _AppLoader(),
          ),
        );

        AppLogger.info('Flutter application started');
      } catch (e, stackTrace) {
        AppLogger.error(
          'Fatal error during application startup',
          error: e,
          stackTrace: stackTrace,
        );

        rethrow;
      }
    },
        (error, stackTrace) {
      AppLogger.error(
        'Unhandled application error',
        error: error,
        stackTrace: stackTrace,
      );
    },
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

      error: (err, stack) {
        AppLogger.error(
          'Application initialization failed',
          error: err,
          stackTrace: stack,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFFFF8F0),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Something went wrong.\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6D4C41),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      },

      data: (_) => const NityaSadhanaApp(),
    );
  }
}
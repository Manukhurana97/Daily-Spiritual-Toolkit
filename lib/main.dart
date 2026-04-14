import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/japa_provider.dart';
import 'providers/panchang_provider.dart';
import 'providers/compass_provider.dart';
import 'providers/settings_provider.dart';

final appInitializedProvider = FutureProvider<bool>((ref) async {
  await ref.read(settingsProvider).initialize();
  await ref.read(japaProvider).initialize();
  await ref.read(panchangProvider).initialize();
  ref.read(compassProvider).initialize();
  return true;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
                  'Naam Jap',
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
      data: (_) => const NaamJapApp(),
    );
  }
}

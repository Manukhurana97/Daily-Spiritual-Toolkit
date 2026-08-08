import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nitya_sadhana/providers/panchang_provider.dart';
import 'package:nitya_sadhana/providers/settings_provider.dart';
import 'package:nitya_sadhana/screens/paywall/paywall_screen.dart';
import 'package:nitya_sadhana/screens/sankalp/sankalp_screen.dart';
import 'package:nitya_sadhana/services/notification_service.dart';
import 'package:nitya_sadhana/services/subscription_service.dart';

import '../core/theme/app_theme.dart';
import '../providers/japa_provider.dart';
import '../providers/sankalp_provider.dart';
import 'japa/japa_screen.dart';
import 'panchang/panchang_screen.dart';
import 'compass/compass_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget with WidgetsBindingObserver{
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  static const _titles = ['Japa', 'Panchang', 'Compass', 'Sankalp', 'Settings'];

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.dispose();
  }

  @override
  void dispose() {
    super.initState();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMuhurtaOnResume();
    }
  }

  Future<void> _refreshMuhurtaOnResume() async {
    try {
      final needsRefresh = await NotificationService.needsRefresh();
      if (!needsRefresh) return;

      final settings = ref.read(settingsProvider);
      final sub = ref.read(subscriptionProvider);
      if (!sub.isPremium) return;

      final hasBrahma = settings.brahmaMuhurtaNotif;
      final hasSandhya = settings.sandhyaKaalNotif;
      if (!hasBrahma && !hasSandhya) return;

      // Refresh panchang first (recalculate sunrise/sunset for new location/day)
      await ref.read(panchangProvider).refreshIfNeeded();
      final panchang = ref.read(panchangProvider);
      if(panchang.days.isEmpty) return;

      await NotificationService.scheduleWeek(
        days: panchang.days,
        brahmaMuhurta: hasBrahma,
        sandhyaKaal: hasSandhya,
        sound: settings.notifSound,
      );
      debugPrint('[HomeShell] Muhurta notifications refreshed on resume');
    } catch (e) {
      debugPrint('[HomeShell] Failed to refresh muhurta on resume: $e');
    }
  }

  static const _screens = [
    JapaScreen(),
    PanchangScreen(),
    CompassScreen(),
    SankalpScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 3) {
            final sub = ref.read(subscriptionProvider);
            if (!sub.isPremium) {
              PaywallScreen.show(context, featureTitle: 'Sankalp (Goals');
              return;
            }
          }
          setState(() => _currentIndex = index);
          if (index == 1) {
            ref.read(panchangProvider).refreshIfNeeded();
          }
          if (index == 3) {
            final mantra = ref
                .read(japaProvider)
                .activeMantra;
            if (mantra != null) {
              ref.read(sankalpProvider).loadForMantra(mantra.id!);
            }
            ref.read(sankalpProvider).loadHistory();
          }
          if (index == 0) {
            // Refresh sankalp badges when remaining to japa
            final mantras = ref.read(japaProvider).mantras;
            if (mantras.isNotEmpty) {
              ref.read(sankalpProvider).loadSankalpMantraIds(
                mantras.where((m) => m.id != null).map((m) => m.id!).toList(),
              );
            }
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa_rounded, color: AppColors.saffron),
            label: 'Japa',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded, color: AppColors.saffron),
            label: 'Panchang',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: AppColors.saffron),
            label: 'Compass',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded, color: AppColors.saffron),
            label: 'Sankalp',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.saffron),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

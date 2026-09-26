import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nitya_sadhana/providers/panchang_provider.dart';
import 'package:nitya_sadhana/providers/settings_provider.dart';
import 'package:nitya_sadhana/screens/paywall/paywall_screen.dart';
import 'package:nitya_sadhana/screens/sankalp/sankalp_screen.dart';
import 'package:nitya_sadhana/services/auth_service.dart';
import 'package:nitya_sadhana/services/backup_service.dart';
import 'package:nitya_sadhana/services/device_service.dart';
import 'package:nitya_sadhana/services/notification_service.dart';
import 'package:nitya_sadhana/services/subscription_service.dart';
import 'package:nitya_sadhana/utils/app_logger.dart';

import '../core/theme/app_theme.dart';
import '../providers/japa_provider.dart';
import '../providers/sankalp_provider.dart';
import 'japa/japa_screen.dart';
import 'panchang/panchang_screen.dart';
import 'compass/compass_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget{
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver{
  int _currentIndex = 0;

  static const _titles = ['Japa', 'Panchang', 'Compass', 'Sankalp', 'Settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // primary user story: new phone -> sign in -> offer a restore.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferRestore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckDeviceResume();
      _refreshMuhurtaOnResume();
    }
  }

  /// A device removed from another phone must find out on foreground
  /// resume, not only on a clod start. refreshDevices() re-readds active devices
  /// WITHOUT re-registering, so a de-authorised devices stage de-authorized
  Future<void> _recheckDeviceResume() async {
    try{
      final auth = ref.read(authServiceProvider);
      final sub = ref.read(subscriptionProvider);
      if (!auth.isSignedIn || !sub.isPremium) return;

      final deviceService = ref.read(deviceServiceProvider);
      final wasAuthorized = deviceService.isAuthorized;
      await deviceService.refreshDevices();
      if (!mounted) return;

      if (wasAuthorized && !deviceService.isAuthorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "You've signed out because your account is active on another device.",
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          )
        );
      }
    } catch (e, st) {
      AppLogger.error('[HomeShell] device re-check failed', error: e, stackTrace: st);
    }
  }

  /// Offer a one-tap restore when this install has no local data but the
  /// account has a cloud snapshot. Shown at most once per install
  Future<void> _maybeOfferRestore() async {
    try {
      final auth = ref.read(authServiceProvider);
      final sub = ref.read(subscriptionProvider);
      if (!auth.isSignedIn || !sub.isPremium) return;

      final backupService = ref.read(backupServiceProvider);
      if (await backupService.hasOfferedRestore()) return;
      if (!await BackupService.isLocalDataEmpty()) return;

      final latest = await backupService.latestbackup();
      if (latest == null || !mounted) return;

      await backupService.markRestoredOffered();

      final accept = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore your data?'),
            content: Text(
              'This device has no saved japa data, but your account has a cloud '
              'backup from ${DateFormat('MMM d, yyyy  h:mm a').format(latest.createdAt)} '
              '(${latest.formattedSize}).\n\n'
              'Restore is now to pick up where you left off.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not now'),
              ),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.saffron,
                    foregroundColor: Colors.white
                  ),
                  child: const Text('Restore'),
              )
            ],
          )
      );
      if (accept != true || !mounted) return;

      final ok = await backupService.restoreBackup(latest.backupId);
      if (!mounted) return;
      if (ok) {
        ref.invalidate(japaProvider);
        ref.invalidate(sankalpProvider);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
              ? 'Restore complete! Undo is available in settings for 7 days.'
              : 'Restore failed. You can retry from Settings.',
            ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      AppLogger.error('[HomeShell] restore offer failed', error: e, stackTrace: st);
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

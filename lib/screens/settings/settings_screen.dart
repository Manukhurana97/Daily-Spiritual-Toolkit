
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nitya_sadhana/screens/paywall/paywall_screen.dart';
import 'package:nitya_sadhana/services/ad_service.dart';
import 'package:nitya_sadhana/services/sadhana_mode_service.dart';
import 'package:nitya_sadhana/services/subscription_service.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mantra.dart';
import '../../providers/japa_provider.dart';
import '../../providers/panchang_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final japa = ref.watch(japaProvider);
    final sub = ref.watch(subscriptionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),

          // ── Mantras Management ──
          SectionCard(
            title: 'My Mantras',
            child: Column(
              children: [
                ...japa.mantras.map((mantra) {
                  final isDefault = mantra.id == settings.defaultMantraId;
                  return _MantraTile(
                    name: mantra.name,
                    actualMantra: mantra.actualMantra,
                    direction: mantra.targetDirection,
                    activeDaysDisplay: mantra.activeDayDisplay,
                    bestTimesDisplay: mantra.bestTimeDisplay,
                    bestTime: mantra.bestTime,
                    isDefault: isDefault,
                    canDelete: japa.mantras.length > 1,
                    onSetDefault: () => settings.setDefaultMantraId(mantra.id),
                    onDelete: () => _confirmDelete(context, ref, mantra),
                    onEdit: () => _showEditMantraDialog(context, ref, mantra),
                    isDark: isDark,
                  );
                }),
                if (japa.mantras.length < sub.maxMantra)
                  _AddMantraButton(
                    onTap: () {
                      if (!sub.isPremium && japa.mantras.length >= FreeTierLimits.maxMantra) {
                        PaywallScreen.show(context, featureTitle: 'Unlimited Mantra');
                        return;
                      }
                      _showAddMantraDialog(context, ref);
                    },
                  ),
                if (!sub.isPremium && japa.mantras.length >= FreeTierLimits.maxMantra)
                  Padding(
                      padding: const EdgeInsetsGeometry.only(top: 8),
                    child: Text(
                      'Free tier: ${FreeTierLimits.maxMantra} mantras. Upgrade for unlimited.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  )
              ],
            ),
          ),

          // ── Appearance ──
          SectionCard(
            title: 'Appearance',
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.palette_rounded,
                  title: 'Theme',
                  isDark: isDark,
                  trailing: FittedBox(
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 16)),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_rounded, size: 16)),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 16)),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (modes) => settings.setThemeMode(modes.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Japa Target
          SectionCard(
              title: 'Japa Target',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mala Size',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.malaSizePresents.map((size) {
                      final selected = settings.malaSize == size;
                      return ChoiceChip(
                          label: Text('$size'),
                          selected: selected,
                        onSelected: (_) {
                            settings.setMalaSize(size);
                            ref.read(japaProvider).updateTargets(malaSize: size, dailyGoal: settings.dailyGoal);
                        },
                        selectedColor: isDark ? AppColors.saffron.withValues(alpha: 0.2) : AppColors.saffronLight,
                        side: BorderSide(color: selected ? AppColors.saffron : (isDark ? AppColors.darkDivider : AppColors.divider)),
                        labelStyle: TextStyle(
                          color: selected ? AppColors.saffron : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text (
                      'Daily Goal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    settings.dailyGoal > 0
                        ? 'Target: ${settings.dailyGoal} japs per day'
                        : 'No daily goal set',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...[0, 100, 500, 1000].map((goal) {
                        final selected = settings.dailyGoal == goal;
                        return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(goal == 0 ? 'Off' : '$goal'),
                                selected: selected,
                              onSelected: (_) {
                                  settings.setDailyGoal(goal);
                                  ref.read(japaProvider).updateTargets(malaSize: settings.malaSize, dailyGoal: goal);
                              },
                              selectedColor: isDark ? AppColors.teal.withValues(alpha: 0.2) : AppColors.tealLight,
                              side: BorderSide(color: selected ? AppColors.teal : (isDark ? AppColors.darkDivider : AppColors.divider)),
                              labelStyle: TextStyle(
                                color: selected ? AppColors.teal : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
          ),

          // ── Notifications ──
          _PremiumSection(
            isPremium: sub.isPremium,
            featureTitle: 'Smart Notifications',
            isDark: isDark,
            child: SectionCard(
            title: 'Notifications',
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Brahma Muhurta',
                  subtitle: '1.5 hours before sunrise (7-day schedule)',
                  value: settings.brahmaMuhurtaNotif,
                  enabled: true,
                  isDark: isDark,
                  onChanged: (v) async {
                    await settings.setBrahmaMuhurtaNotif(v);
                    if (v) {
                      await NotificationService.requestPermission();
                      await _rescheduleWeek(ref, settings);
                    }
                  },
                ),
                const Divider(height: 4),
                _SwitchRow(
                  icon: Icons.nights_stay_rounded,
                  title: 'Sandhya Kaal',
                  subtitle: 'At sunset time  (7-day schedule)',
                  value: settings.sandhyaKaalNotif,
                  enabled: true,
                  isDark: isDark,
                  onChanged: (v) async {
                    await settings.setSandhyaKaalNotif(v);
                    if (v) {
                      await NotificationService.requestPermission();
                    }
                    await _rescheduleWeek(ref, settings);
                  },
                ),

                if(settings.brahmaMuhurtaNotif || settings.sandhyaKaalNotif) ...[
                  const Divider(height: 4),
                  _SettingRow(
                      icon: Icons.music_note_rounded,
                      title: 'Alarm sound',
                      isDark: isDark,
                      trailing: DropdownButton<String>(
                          value: settings.notifSound,
                          underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                        items: NotificationService.soundOptions.entries.map((e) {
                          return DropdownMenuItem(value: e.key, child: Text(e.value));
                        }).toList(),
                        onChanged: (v) async {
                            if (v == null) return;
                            await settings.setNotifSound(v);
                            await _rescheduleWeek(ref, settings);
                        },
                      ),
                  ),
                ],
              ],
            ),
            )
          ),

          // Sadhana Mode (DND
          _PremiumSection(
            isPremium: sub.isPremium,
            featureTitle: 'Sadhana Mode',
            isDark: isDark,
            child: _SadhanaModeSetting(isDark: isDark),
          ),

          // ── Background Sound ──
          _PremiumSection(
            isPremium: sub.isPremium,
            featureTitle: 'Background Sound',
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(''
                    'Play soothing sounds during japa. Tap the music icon on the japa screen to choose.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8,),
                Consumer(
                    builder: (_, ref, __) {
                      final audio = ref.watch(audioServiceProvider);
                      return Column(
                        children: [
                          _SettingRow(
                              icon: Icons.volume_up_rounded,
                              title: 'Volume',
                              isDark: isDark,
                              trailing: SizedBox(
                                width: 120,
                                child: Slider(
                                  value: audio.volume,
                                  onChanged: (v) => audio.setVolume(v),
                                  activeColor: AppColors.saffron,
                                ),
                              ),
                          ),
                        ],
                      );
                    }),
              ],
            ),
          ),


          // ── Data ──
          SectionCard(
            title: 'Data',
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.file_download_rounded,
                  title: 'Export Japa History',
                  subtitle: 'Download CSV file',
                  dense: true,
                  onTap: () async {
                    final mantra = japa.activeMantra;
                    final msg = await ExportService.exportSessions(
                      mantraId: mantra?.id,
                      mantraName: mantra?.name ?? 'All',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                _ResetAllButton(onTap: () => _confirmResetAll(context, ref)),
              ],
            ),
          ),

          // Account
          Consumer(
              builder: (context, ref, _) {
                final auth = ref.watch(authServiceProvider);
                return SectionCard(
                    title: 'Account',
                    child: auth.isSignedIn
                      ? Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: auth.photoUrl != null
                                    ? NetworkImage(auth.photoUrl!)
                                  : null,
                                  backgroundColor: isDark ? AppColors.darkCard : AppColors.cream,
                                  child: auth.photoUrl == null
                                  ? Icon(Icons.person_rounded, color: AppColors.saffron, size: 24,)
                                      : null,
                                ),
                                const SizedBox(width: 12,),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (auth.displayName != null && auth.displayName!.isNotEmpty)
                                        Text(
                                          auth.displayName!,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                          ),
                                        ),
                                      if (auth.email != null)
                                        Text(
                                          auth.email!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12,),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Sign Out'),
                                          content: const Text('Are you sure you want sign out?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
                                          ],
                                        )
                                    );
                                    if (confirm == true) {
                                      await auth.signOut();
                                    }
                                  },
                                  icon: const Icon(Icons.logout_rounded, size: 18),
                                  label: const Text('Sign Out'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.deepMaroon
                                ),
                              ),
                            )
                          ],
                        )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in to sync purchases across devices',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12,),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              onPressed: auth.isLoading ? null : () => auth.signInWithGoogle(),
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                              label: const Text('Continue with Google'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                                onPressed: auth.isLoading ? null : () => auth.signInWithApple(),
                                icon: const Icon(Icons.apple_rounded, size: 22),
                                label: const Text("Continue with Apple"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white : Colors.black,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (auth.isLoading)
                            const Padding(
                                padding: EdgeInsets.only(top: 12),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2,),),
                            ),
                          if (auth.error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                auth.error!,
                                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                              ),
                            )
                        ]
                      ],
                    )
                );
              }
          ),

          // Subscription
          SectionCard(
            title: 'Subscription',
              child: Column(
                children: [
                  _SettingRow(
                      icon: sub.isPremium ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
                      title: sub.isPremium ? 'Premium Action' : 'Free Tier',
                    isDark: isDark,
                    trailing: sub.isPremium
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 20,)
                    : ElevatedButton (
                          onPressed: () => PaywallScreen.show(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      child: const Text('Upgrade'),
                      ),
                  ),
                  // DEV ONLY: Toggle premium for testing (removed in release builds)
                  if (kDebugMode)
                    TextButton(
                      onPressed: () => ref.read(subscriptionProvider).devTogglePremium(),
                      child: Text(
                        'DEV Toggle Premium (${sub.isPremium ? "ON" : "OFF"})',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    )
                ],
              ),
          ),

          // ── About ──
          SectionCard(
            title: 'About',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 2.0.0',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.tagline,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.teal.withValues(alpha: 0.12) : AppColors.tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, size: 18, color: AppColors.teal),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your data stays on device. No tracking',
                          style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Banner Ad (free users only)
          if (!sub.isPremium)
            const _BannerAdWidget(),
        ],
      ),
    );
  }

  void _confirmResetAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'Are you sure you want to reset everything?\n\n'
          'This will delete all mantras, sessions, and stats. '
          'Default mantras will be restored. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(japaProvider).resetAll();
              await ref.read(settingsProvider).setDefaultMantraId(null);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data has been reset.'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _rescheduleWeek(WidgetRef ref, SettingsNotifier settings) async {
    final panchang = ref.read(panchangProvider);
    if(panchang.days.isEmpty) return;

    final hasBrahma = settings.brahmaMuhurtaNotif;
    final hasSandhya = settings.sandhyaKaalNotif;

    if(!hasBrahma && !hasSandhya) {
      await NotificationService.cancelBrahmaMuhurta();
      await NotificationService.cancelSandhyaKaal();
      return;
    }

    await NotificationService.scheduleWeek(
      days: panchang.days,
      brahmaMuhurta: hasBrahma,
      sandhyaKaal: hasSandhya,
      sound: settings.notifSound,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Mantra mantra) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Mantra'),
        content: Text('Remove "${mantra.name}" and all its jap history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(japaProvider).removeMantra(mantra);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditMantraDialog(BuildContext context, WidgetRef ref, Mantra mantra) {
    final nameCtrl = TextEditingController(text: mantra.name);
    final mantraCtrl = TextEditingController(text: mantra.actualMantra ?? '');
    final dirCtrl = TextEditingController(text: mantra.targetDirection ?? '');
    final selectedDays = <String>{...mantra.activeDayList};
    var bestTime = mantra.bestTime;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              title: const Text('Edit Mantra'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Mantra Name *',
                        hintText: 'e.g Radha',
                        border: const OutlineInputBorder(),
                        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: mantraCtrl,
                      textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Description / Actual Mantra',
                          hintText: 'e.g Full mantra text or notes',
                          border: const OutlineInputBorder(),
                          helperText: 'optional - full text or description',
                          helperMaxLines: 2,
                        ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: dirCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Facing Direction',
                        hintText: 'e.g East, West, North-east',
                        border: const OutlineInputBorder(),
                        helperText: 'Optional - direction to face during japa',
                        helperMaxLines: 2,
                        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Active Day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: Mantra.allDayCodes.map((day) {
                        final selected = selectedDays.contains(day);
                        return FilterChip(
                            label: Text(Mantra.dayLabels[day]!, style: TextStyle(fontSize: 12, color: selected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
                            selected: selected,
                            onSelected: (v) => setDialogState(() {
                              v ? selectedDays.add(day) : selectedDays.remove(day);
                            }),
                          selectedColor: AppColors.saffron,
                          checkmarkColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Text('Best Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'morning', icon: Icon(Icons.wb_sunny_rounded, size: 16), label: Text('Morning', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: 'anytime', icon: Icon(Icons.access_time_rounded, size: 16), label: Text('Anytime', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: 'evening', icon: Icon(Icons.nights_stay_rounded, size: 16), label: Text('Evening', style: TextStyle(fontSize: 12))),
                        ],
                        selected: {bestTime},
                        onSelectionChanged: (v) => setDialogState(() => bestTime = v.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      if (selectedDays.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select at least one day '), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      final activeDays = selectedDays.length == 7
                        ? 'all'
                      : Mantra.allDayCodes.where(selectedDays.contains).join(',');
                      ref.read(japaProvider).updateMantraDetails(
                          mantra.copyWith(
                            name: name,
                            actualMantra: mantraCtrl.text.trim().isEmpty ? null : mantraCtrl.text.trim(),
                            targetDirection: dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
                            clearActualMantra: mantraCtrl.text.trim().isEmpty,
                            clearTargetDirection: dirCtrl.text.trim().isEmpty,
                            activeDays: activeDays,
                            bestTime: bestTime
                          )
                      );
                      Navigator.pop(ctx);
                    },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showAddMantraDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final mantraCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final selectedDays = <String>{...Mantra.allDayCodes};
    var bestTime = 'anytime';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              title: const Text('Add Mantra'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                          labelText: 'Mantra Name *',
                          hintText: 'e.g. Om Namah Shivaya',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: mantraCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Full Mantra Text',
                        hintText: 'e.g/ Om Namah Bhagsvate Vasudevaya',
                        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: dirCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Facing Direction',
                        hintText: 'e.g East, West, North-East',
                        helperText: 'Optional - direction to face during japa',
                        helperMaxLines: 2,
                        labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mantra name is required'), behavior: SnackBarBehavior.floating,)
                      );
                      return;
                    }
                    ref.read(japaProvider).addMantra(
                      name,
                      actualMantra: mantraCtrl.text.trim().isEmpty ? null: mantraCtrl.text.trim(),
                      targetDirection: dirCtrl.text.trim().isEmpty ? null: dirCtrl.text.trim(),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
            }
        );
      }
    );
  }
}

class _MantraTile extends StatelessWidget {
  final String name;
  final String? actualMantra;
  final String? direction;
  final String activeDaysDisplay;
  final String bestTimesDisplay;
  final String bestTime;
  final bool isDefault;
  final bool canDelete;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final bool isDark;

  const _MantraTile({
    required this.name,
    this.actualMantra,
    this.direction,
    required this.activeDaysDisplay,
    required this.bestTimesDisplay,
    required this.bestTime,
    required this.isDefault,
    required this.canDelete,
    required this.onSetDefault,
    required this.onDelete,
    required this.onEdit,
    required this.isDark,
  });

  IconData get _bestTimeIcon {
    switch (bestTime) {
      case 'morning': return Icons.wb_sunny_rounded;
      case 'evening': return Icons.nights_stay_rounded;
      default: return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (direction != null) subtitleParts.add('Face $direction');
    if (activeDaysDisplay != 'Every day') subtitleParts.add(activeDaysDisplay);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDefault
              ? (isDark ? AppColors.saffron.withValues(alpha: 0.12) : AppColors.saffronLight)
              : (isDark ? AppColors.darkCard : AppColors.cream),
          borderRadius: BorderRadius.circular(10),
          border: isDefault ? Border.all(color: AppColors.saffron.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.spa_rounded, size: 20, color: isDefault ? AppColors.saffron : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isDefault ? FontWeight.w600 : FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' . '),
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  if (bestTime != 'anytime')
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_bestTimeIcon, size: 12, color: bestTime == 'morning' ? Colors.orange : Colors.indigo),
                            const SizedBox(width: 3,),
                            Text(bestTimesDisplay, style: TextStyle(fontSize: 11, color: bestTime == 'morning' ? Colors.orange : Colors.indigo)),
                          ],
                        ),
                    ),
                ],
              ),
            ),
            if (isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.saffron.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Default', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.saffron)),
              ),
            PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'default': onSetDefault();
                  case 'edit': onEdit();
                  case 'delete': onDelete();
                }
              },
              itemBuilder: (_) => [
                if (!isDefault) const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: Colors.red))),
              ],
              icon: const Icon(Icons.more_vert, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final bool isDark;

  const _SettingRow({required this.icon, required this.title, required this.trailing, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.saffron),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.saffron),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeTrackColor: AppColors.saffron.withValues(alpha: 0.5),
              thumbColor: WidgetStatePropertyAll(AppColors.saffron),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dense;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dense) {
      return InkWell(
        onTap: onTap ,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.saffron),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkCard : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.divider, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, size: 24, color: AppColors.saffron),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                    ],
                  ),
                ),

                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever_rounded, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Reset All Data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMantraButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMantraButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.saffron.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: AppColors.saffron),
                SizedBox(width: 6),
                Text('Add Mantra', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.saffron)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SadhanaModeSetting extends ConsumerStatefulWidget {
  final bool isDark;
  const _SadhanaModeSetting({required this.isDark});

  @override
  ConsumerState<_SadhanaModeSetting> createState() => _SadhanaModeSec();
}

class _SadhanaModeSec extends ConsumerState<_SadhanaModeSetting> {
  final int _timerMinutes = 0; // 0 = no Timer

  void _showIosFocusGuide(BuildContext context) {
    final isDark = widget.isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.do_not_disturb_on_rounded, size: 24, color: AppColors.saffron),
                  const SizedBox(width: 10,),
                  Text(
                    'Enable Focus Mode on iPhone',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _iOSStep('1', 'Open iPhone Settings -> Focus', isDark),
              _iOSStep('2', 'Tap "Do Not Disturb" or create a custom Focus', isDark),
              _iOSStep('3', 'Turn it on before starting year sadhana', isDark),
              _iOSStep('4', 'Or use Control Center - swipe down and tap the moon icon 🌙', isDark),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                          'iOS does not allow apps to control DND directly. '
                              'Please use the build-in Focus Mode for a distraction-free experience. ',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                ),
              )
            ],
          ),
      )
    );
  }

  Widget _iOSStep(String num, String text, bool isDark) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.saffron.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(num, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.saffron)),
          ),
          const SizedBox(height: 10),
          Expanded(
              child: Text(
                text, 
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
              ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final sadhana = ref.watch(sadhanaModeProvider);
    final isDark = widget.isDark;
    
    return SectionCard(
      title: 'Sadhana Mode',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Silence all distractions during your spiritual practice.',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Active status banner
          if (sadhana.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.self_improvement_rounded, size: 24, color: AppColors.teal),
                  const SizedBox(width: 10,),
                  Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sadhana Mode Active',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.teal),
                          ),
                          if (sadhana.timerDuration != null)
                            Text(
                              'Auto-off timer set',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            ),
                        ],
                      ),
                  ),
                  TextButton(
                      onPressed: () => sadhana.deactivate(),
                      child: const Text('End', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

          if (!sadhana.isActive) ...[
            // Timer selection
            Text(
              'Auto-off Timer (optional)',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 30, 60, 90, 120].map((mins) {
                final selected = _timerMinutes == mins;
                return ChoiceChip(
                    label: Text(mins == 0 ? 'Manual' : '$mins min'),
                    selected: selected,
                  onSelected: (_) => setState(() => _timerMinutes == mins),
                  selectedColor: isDark ? AppColors.saffron.withValues(alpha: 0.2) : AppColors.saffronLight,
                  side: BorderSide(
                    color: selected ? AppColors.saffron : (isDark ? AppColors.darkDivider : AppColors.divider),
                  ),
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.saffron : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Activate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: () async {
                    // On Android: check & request DND permission if needed
                    if (Platform.isAndroid && !sadhana.hasAndroidDndPermission) {
                      await sadhana.requestAndroidPermission();
                    }
                    // On iOS: show focus guide on first use
                    if (Platform.isIOS && !sadhana.iosGuideShown) {
                      sadhana.markIosGuideShown();
                      if (context.mounted) _showIosFocusGuide(context);
                    }
                    final duration = _timerMinutes > 0 ? Duration(minutes: _timerMinutes) : null;
                    sadhana.activate(duration: duration);
                  },
                icon: const Icon(Icons.self_improvement_rounded),
                  label: Text(_timerMinutes > 0
                  ? 'Start Sadhana Mode ($_timerMinutes min)'
                      : 'Start Sadhana Mode'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.saffron,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // Platform info
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Platform.isAndroid ? Icons.android_rounded : Icons.apple_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                        Platform.isAndroid
                            ? 'Activates system Do Not Disturb - silences calls, messages & notifications,'
                            : 'Tap a get a guide on enabling iOS Focus Mode for distraction-free practice.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Premium Gate Overlay

class _PremiumSection extends StatelessWidget {
  final bool isPremium;
  final String featureTitle;
  final bool isDark;
  final Widget child;

  const _PremiumSection({
    required this.isPremium,
    required this.featureTitle,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isPremium) return child;

    return Stack(
      children: [
        Opacity(
            opacity: 0.4,
          child: IgnorePointer(child: child),
        ),
        Positioned.fill(
            child: GestureDetector(
              onTap: () => PaywallScreen.show(context, featureTitle: featureTitle),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      )
                    ]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 16, color: AppColors.saffron),
                      const SizedBox(width: 8),
                      Text(
                        'Unlock $featureTitle',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.saffron,
                        ),
                      ),
                      const SizedBox(width: 4,),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.saffron),
                    ],
                  ),
                ),
              ),
            )
        )
      ],
    );
  }
}

class _BannerAdWidget extends ConsumerStatefulWidget {
  const _BannerAdWidget();

  @override
  ConsumerState<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<_BannerAdWidget> {
  @override
  void initState() {
    super.initState();
    ref.read(adProviderService).loadBanner();
  }

  @override
  void dispose() {
    ref.read(adProviderService).disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adService = ref.watch(adProviderService);
    final banner = adService.bannerId;
    if (!adService.isBannerReady || banner == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 16),
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}
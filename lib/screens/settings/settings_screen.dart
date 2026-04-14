import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/japa_provider.dart';
import '../../providers/panchang_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/notification_service.dart';
import '../../services/purchase_service.dart';
import '../../screens/paywall/paywall_screen.dart';
import '../../screens/sankalp/sankalp_screen.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final japa = ref.watch(japaProvider);
    final auth = ref.watch(authProvider);
    final purchase = ref.watch(purchaseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPro = purchase.isPro;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),

          // ── Account ──
          SectionCard(
            title: 'Account',
            child: auth.isSignedIn
                ? Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.saffronLight,
                            child: Text(
                              (auth.displayName ?? auth.email ?? '?')[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.saffron),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.displayName ?? 'User',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  auth.email ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPro)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.saffron.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.saffron),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref.read(authProvider).signOut();
                            await ref.read(purchaseProvider).onUserSignedOut();
                          },
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Text(
                        'Sign in to unlock Pro features and sync purchases.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  final user = await ref.read(authProvider).signInWithGoogle();
                                  if (user != null) {
                                    await ref.read(purchaseProvider).onUserSignedIn(user.uid);
                                  }
                                },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Sign in with Google'),
                        ),
                      ),
                      if (Platform.isIOS) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    final user = await ref.read(authProvider).signInWithApple();
                                    if (user != null) {
                                      await ref.read(purchaseProvider).onUserSignedIn(user.uid);
                                    }
                                  },
                            icon: const Icon(Icons.apple_rounded, size: 18),
                            label: const Text('Sign in with Apple'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // ── Pro Unlock ──
          if (!isPro)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => PaywallScreen.show(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.saffron, AppColors.deepMaroon],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unlock Pro', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              Text('Unlimited mantras, Sankalp, sounds & more', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Sankalp (Pro) ──
          _ProGatedTile(
            isPro: isPro,
            icon: Icons.auto_awesome_rounded,
            title: 'Sankalp (Vow)',
            subtitle: 'Set a chanting goal with deadline',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SankalpScreen()),
            ),
            onLocked: () => PaywallScreen.show(context),
          ),

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
                    isDefault: isDefault,
                    canDelete: japa.mantras.length > 1,
                    onSetDefault: () => settings.setDefaultMantraId(mantra.id),
                    onDelete: () => _confirmDelete(context, ref, mantra),
                    onRename: () => _showRenameDialog(context, ref, mantra),
                    isDark: isDark,
                  );
                }),
                if (japa.mantras.length < (isPro ? 50 : AppConstants.maxMantras))
                  _AddMantraButton(
                    onTap: () => _showAddMantraDialog(context, ref, isPro: isPro),
                  ),
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
                  trailing: SegmentedButton<ThemeMode>(
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
              ],
            ),
          ),

          // ── Notifications (Pro) ──
          SectionCard(
            title: 'Notifications',
            trailing: !isPro
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.saffron.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.saffron)),
                  )
                : null,
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Brahma Muhurta',
                  subtitle: '1.5 hours before sunrise',
                  value: settings.brahmaMuhurtaNotif,
                  enabled: isPro,
                  isDark: isDark,
                  onChanged: (v) async {
                    await settings.setBrahmaMuhurtaNotif(v);
                    if (v) {
                      await NotificationService.requestPermission();
                      final sunrise = ref.read(panchangProvider).todaySunrise;
                      if (sunrise != null) {
                        await NotificationService.scheduleBrahmaMuhurta(sunrise);
                      }
                    } else {
                      await NotificationService.cancelBrahmaMuhurta();
                    }
                  },
                ),
                const Divider(height: 4),
                _SwitchRow(
                  icon: Icons.nights_stay_rounded,
                  title: 'Sandhya Kaal',
                  subtitle: 'At sunset time',
                  value: settings.sandhyaKaalNotif,
                  enabled: isPro,
                  isDark: isDark,
                  onChanged: (v) async {
                    await settings.setSandhyaKaalNotif(v);
                    if (v) {
                      await NotificationService.requestPermission();
                      final sunset = ref.read(panchangProvider).todaySunset;
                      if (sunset != null) {
                        await NotificationService.scheduleSandhyaKaal(sunset);
                      }
                    } else {
                      await NotificationService.cancelSandhyaKaal();
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Background Sound ──
          SectionCard(
            title: 'Background Sound',
            trailing: !isPro
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.saffron.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.saffron)),
                  )
                : null,
            child: Opacity(
              opacity: isPro ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Play soothing sounds during japa. Tap the music icon on the Japa screen to choose.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(builder: (_, ref, __) {
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
                              onChanged: isPro ? (v) => audio.setVolume(v) : null,
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
          ),

          // ── Data ──
          SectionCard(
            title: 'Data',
            child: Column(
              children: [
                _ProGatedTile(
                  isPro: isPro,
                  icon: Icons.file_download_rounded,
                  title: 'Export Japa History',
                  subtitle: 'Download CSV file',
                  dense: true,
                  onTap: () {
                    final mantra = japa.activeMantra;
                    ExportService.exportSessions(
                      mantraId: mantra?.id,
                      mantraName: mantra?.name ?? 'All',
                    );
                  },
                  onLocked: () => PaywallScreen.show(context),
                ),
                const SizedBox(height: 8),
                _ResetAllButton(onTap: () => _confirmResetAll(context, ref)),
              ],
            ),
          ),

          // ── Language ──
          SectionCard(
            title: 'Language',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App language follows your system language by default.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, size: 20, color: AppColors.teal),
                      const SizedBox(width: 10),
                      Text(
                        settings.locale == 'system' ? 'System Default' : settings.locale,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  'Version 1.5.0',
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
                          'No ads. Sign in only for Pro. Data stays on device.',
                          style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, mantra) {
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

  void _showRenameDialog(BuildContext context, WidgetRef ref, mantra) {
    final controller = TextEditingController(text: mantra.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Mantra'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter mantra name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(japaProvider).renameMantra(mantra, name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddMantraDialog(BuildContext context, WidgetRef ref, {bool isPro = false}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Mantra'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Om Namah Shivaya', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(japaProvider).addMantra(name, isPro: isPro);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _MantraTile extends StatelessWidget {
  final String name;
  final String? actualMantra;
  final String? direction;
  final bool isDefault;
  final bool canDelete;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final bool isDark;

  const _MantraTile({
    required this.name,
    this.actualMantra,
    this.direction,
    required this.isDefault,
    required this.canDelete,
    required this.onSetDefault,
    required this.onDelete,
    required this.onRename,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
                  if (direction != null)
                    Text(
                      'Face ${direction!}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
                  case 'rename': onRename();
                  case 'delete': onDelete();
                }
              },
              itemBuilder: (_) => [
                if (!isDefault) const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
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
              activeColor: AppColors.saffron,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProGatedTile extends StatelessWidget {
  final bool isPro;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onLocked;
  final bool dense;

  const _ProGatedTile({
    required this.isPro,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onLocked,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dense) {
      return InkWell(
        onTap: isPro ? onTap : onLocked,
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
              if (!isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.saffron.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.saffron)),
                )
              else
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
          onTap: isPro ? onTap : onLocked,
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
                if (!isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.saffron.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.saffron)),
                  )
                else
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

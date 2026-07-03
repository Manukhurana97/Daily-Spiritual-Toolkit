
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mantra.dart';
import '../../providers/japa_provider.dart';
import '../../providers/panchang_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_service.dart';
import '../../services/export_service.dart';
import '../../services/notification_service.dart';
import '../../screens/sankalp/sankalp_screen.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final japa = ref.watch(japaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 16),

          // Sankalp
          _SettingsTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Sankalp (Vow)',
            subtitle: 'Set a chanting goal with deadline',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SankalpScreen()),
            ),
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
                    onEdit: () => _showEditMantraDialog(context, ref, mantra),
                    isDark: isDark,
                  );
                }),
                if (japa.mantras.length < AppConstants.maxMantras)
                  _AddMantraButton(
                    onTap: () => _showAddMantraDialog(context, ref),
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
          SectionCard(
            title: 'Notifications',
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.wb_twilight_rounded,
                  title: 'Brahma Muhurta',
                  subtitle: '1.5 hours before sunrise',
                  value: settings.brahmaMuhurtaNotif,
                  enabled: true,
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
                  enabled: true,
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
                          'No ads. Your data stays on device.',
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

    showDialog(
      context: context,
      builder: (ctx) {
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
                  ref.read(japaProvider).updateMantraDetails(
                      mantra.copyWith(
                        name: name,
                        actualMantra: mantraCtrl.text.trim().isEmpty ? null : mantraCtrl.text.trim(),
                        targetDirection: dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
                        clearActualMantra: mantraCtrl.text.trim().isEmpty,
                        clearTargetDirection: dirCtrl.text.trim().isEmpty,
                      )
                  );
                  Navigator.pop(ctx);
                }, child: const Text('Save'),
            ),
          ],
        );
      }
    );
  }

  void _showAddMantraDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final mantraCtrl = TextEditingController();
    final dirCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
        title: const Text('Add Mantra'),
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
}

class _MantraTile extends StatelessWidget {
  final String name;
  final String? actualMantra;
  final String? direction;
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
    required this.isDefault,
    required this.canDelete,
    required this.onSetDefault,
    required this.onDelete,
    required this.onEdit,
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
              activeColor: AppColors.saffron,
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

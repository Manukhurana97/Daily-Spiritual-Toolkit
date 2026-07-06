import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nitya_sadhana/providers/settings_provider.dart';
import 'package:nitya_sadhana/providers/stats_provider.dart';
import 'package:nitya_sadhana/services/sadhana_mode_service.dart';
import 'package:nitya_sadhana/widgets/section_card.dart';
import 'package:nitya_sadhana/widgets/streak_chart.dart';

import '../../core/theme/app_theme.dart';
import '../../models/japa_stats.dart';
import '../../providers/japa_provider.dart';
import '../../services/audio_service.dart';
import '../../services/volume_button_service.dart';
import '../../widgets/stat_card.dart';

class JapaScreen extends ConsumerStatefulWidget {
  const JapaScreen({super.key});

  @override
  ConsumerState<JapaScreen> createState() => _JapaScreenState();
}

class _JapaScreenState extends ConsumerState<JapaScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  final _volumeService = VolumeButtonService();
  StreamSubscription<void>? _volumeSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _volumeSub = _volumeService.onVolumeUp.listen((_) => _onTap());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _volumeSub?.cancel();
    _volumeService.dispose();
    super.dispose();
  }

  void _onTap() {
    final japa = ref.read(japaProvider);
    final accepted = japa.tap();
    if (accepted) {
      HapticFeedback.lightImpact();
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final japa = ref.watch(japaProvider);
    final audio = ref.watch(audioServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (japa.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = ref.watch(settingsProvider);
    final malaSize = japa.malaSize;
    final malaProgress = japa.currentMalaProgress;
    final progressFraction = malaProgress / malaSize;
    final directionHint = japa.activeMantra?.targetDirection;

    // Sync target settings on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (japa.malaSize != settings.malaSize ||
          japa.dailyGoal != settings.dailyGoal) {
        japa.updateTargets(
          malaSize: settings.malaSize,
          dailyGoal: settings.dailyGoal,
        );
      }
    });

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Mantra Selector + Audio toggle
          SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MantraSelector(japa: japa, isDark: isDark),
                    ),
                    _SadhanaModeChip(),
                    _AudioToggle(audio: audio),
                  ],
                ),

                // Direction hint
                if (directionHint != null && directionHint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            size: 16,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Face ${directionHint[0].toUpperCase()}${directionHint.substring(1)} for this mantra',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Counter Area with glow
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.42,
                  child: Center(
                    child: GestureDetector(
                      onTap: _onTap,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return _CounterOrb(
                              count: malaProgress,
                              total: malaSize,
                              progress: progressFraction,
                              completedMalas: japa.completedMala,
                              glowIntensity: _glowAnimation.value,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (japa.hasSession) ...[
                        _ActionChip(
                          label: 'End Session',
                          icon: Icons.stop_circle_outlined,
                          color: AppColors.deepMaroon,
                          onTap: () {
                            japa.endSession();
                            ref.read(audioServiceProvider).stop();
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      _ActionChip(
                        label: 'Reset',
                        icon: Icons.refresh_rounded,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        onTap: () => japa.resetCounter(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Daily Goal Progress
                if (japa.dailyGoal > 0)
                  _DailyGoalBar(
                    current: japa.stats.todayCount,
                    goal: japa.dailyGoal,
                    isDark: isDark,
                  ),

                // Stats Row
                _StatsRow(stats: japa.stats),
                const SizedBox(height: 8),

                // Streak & Weekly Chart
                if (japa.activeMantra != null)
                  _StreakSection(
                    mantraId: japa.activeMantra!.id!,
                    isDark: isDark,
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SadhanaModeChip extends ConsumerWidget {
  const _SadhanaModeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sadhana = ref.watch(sadhanaModeProvider);

    return GestureDetector(
      onTap: () {
        if (sadhana.isActive) {
          sadhana.deactivate();
        } else {
          sadhana.activate();
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: sadhana.isActive
                ? AppColors.teal.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            sadhana.isActive
                ? Icons.do_not_disturb_on_rounded
                : Icons.do_not_disturb_off_rounded,
            size: 22,
            color: sadhana.isActive ? AppColors.teal : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AudioToggle extends StatelessWidget {
  final AudioService audio;
  const _AudioToggle({required this.audio});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SoundType?>(
      icon: Icon(
        audio.isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
        color: audio.isPlaying ? AppColors.saffron : AppColors.textSecondary,
        size: 22,
      ),
      onSelected: (type) {
        if (type == null) {
          audio.stop();
        } else {
          audio.toggle(type);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: SoundType.tanpura, child: Text('Tanpura')),
        const PopupMenuItem(
          value: SoundType.templeBells,
          child: Text('Temple Bells'),
        ),
        const PopupMenuItem(
          value: SoundType.river,
          child: Text('Flowing River'),
        ),
        if (audio.isPlaying)
          const PopupMenuItem(
            value: null,
            child: Text('Stop', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _MantraSelector extends StatelessWidget {
  final JapaNotifier japa;
  final bool isDark;
  const _MantraSelector({required this.japa, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 4),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: japa.mantras.length,
          separatorBuilder: (_, i) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final mantra = japa.mantras[index];
            final isActive = mantra == japa.activeMantra;
            return ChoiceChip(
              label: Text(mantra.name),
              selected: isActive,
              onSelected: (_) => japa.selectMantra(mantra),
              selectedColor: isDark
                  ? AppColors.saffron.withValues(alpha: 0.2)
                  : AppColors.saffronLight,
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              side: BorderSide(
                color: isActive
                    ? AppColors.saffron
                    : (isDark ? AppColors.darkDivider : AppColors.divider),
              ),
              labelStyle: TextStyle(
                color: isActive
                    ? AppColors.saffron
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CounterOrb extends StatelessWidget {
  final int count;
  final int total;
  final double progress;
  final int completedMalas;
  final double glowIntensity;
  final bool isDark;

  const _CounterOrb({
    required this.count,
    required this.total,
    required this.progress,
    required this.completedMalas,
    required this.glowIntensity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.62;
    // Glow intensifies as user approaches 108
    final glowAlpha = 0.1 + (progress * 0.4) + (glowIntensity * progress * 0.2);
    final glowColor = Color.lerp(AppColors.saffron, AppColors.gold, progress)!;
    final isNearComplete = progress > 0.9;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                isDark ? AppColors.darkDivider : AppColors.divider,
              ),
            ),
          ),
          // Progress ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                Color.lerp(AppColors.saffron, AppColors.deepMaroon, progress)!,
              ),
            ),
          ),
          // Inner tap area with dynamic glow
          Container(
            width: size - 32,
            height: size - 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkBg]
                    : [AppColors.saffronLight, AppColors.cream],
                stops: const [0.3, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: glowAlpha),
                  blurRadius: 20 + (progress * 30),
                  spreadRadius: 2 + (progress * 8),
                ),
                if (isNearComplete)
                  BoxShadow(
                    color: AppColors.gold.withValues(
                      alpha: glowIntensity * 0.3,
                    ),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shimmer effect near completion
                Transform.translate(
                  offset: isNearComplete
                      ? Offset(sin(glowIntensity * pi * 4) * 1.5, 0)
                      : Offset.zero,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  'of $total',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (completedMalas > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.saffron.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedMalas mala${completedMalas > 1 ? 's' : ''} done',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.saffron,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyGoalBar extends StatelessWidget {
  final int current;
  final int goal;
  final bool isDark;

  const _DailyGoalBar({
    required this.current,
    required this.goal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (current / goal).clamp(0.0, 1.0);
    final reached = current >= goal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 16,
                color: reached ? AppColors.gold : AppColors.teal,
              ),
              const SizedBox(width: 6),
              Text(
                reached ? 'Daily goal reached!' : '$current / $goal today',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: reached
                      ? AppColors.gold
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: isDark
                  ? AppColors.darkDivider
                  : AppColors.divider,
              valueColor: AlwaysStoppedAnimation(
                (reached ? AppColors.gold : AppColors.teal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final JapaStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    String lastSessionText = '—';
    if (stats.lastSession != null) {
      final ls = stats.lastSession!;
      final mins = ls.duration.inMinutes;
      lastSessionText = '${ls.count} japs${mins > 0 ? ' · ${mins}m' : ''}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              label: 'Today',
              value: '${stats.todayCount}',
              icon: Icons.today_rounded,
              accentColor: AppColors.teal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              label: 'Total',
              value: '${stats.totalCount}',
              icon: Icons.all_inclusive_rounded,
              accentColor: AppColors.saffron,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              label: 'Last Session',
              value: lastSessionText,
              icon: Icons.history_rounded,
              accentColor: AppColors.deepMaroon,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakSection extends ConsumerStatefulWidget {
  final int mantraId;
  final bool isDark;

  const _StreakSection({required this.mantraId, required this.isDark});

  @override
  ConsumerState<_StreakSection> createState() => _StreakSectionState();
}

class _StreakSectionState extends ConsumerState<_StreakSection> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(statsProvider).loadForMantra(widget.mantraId);
    });
  }

  @override
  void didUpdateWidget(covariant _StreakSection old) {
    super.didUpdateWidget(old);
    if (old.mantraId != widget.mantraId) {
      ref.read(statsProvider).loadForMantra(widget.mantraId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    if (stats.isLoading || stats.weeklyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Weekly Progress',
      child: StreakChart(data: stats.weeklyData, streak: stats.currentStreak),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/japa_stats.dart';
import '../../providers/japa_provider.dart';
import '../../widgets/stat_card.dart';

class JapaScreen extends ConsumerStatefulWidget {
  const JapaScreen({super.key});

  @override
  ConsumerState<JapaScreen> createState() => _JapaScreenState();
}

class _JapaScreenState extends ConsumerState<JapaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

    if (japa.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final malaProgress = japa.currentMalaProgress;
    final progressFraction = malaProgress / AppConstants.malaSize;

    return SafeArea(
      child: Column(
        children: [
          // ── Mantra Selector ──
          _MantraSelector(japa: japa),

          // ── Counter Area ──
          Expanded(
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
                  child: _CounterOrb(
                    count: malaProgress,
                    total: AppConstants.malaSize,
                    progress: progressFraction,
                    completedMalas: japa.completedMalas,
                  ),
                ),
              ),
            ),
          ),

          // ── Actions ──
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
                    onTap: () => japa.endSession(),
                  ),
                  const SizedBox(width: 12),
                ],
                _ActionChip(
                  label: 'Reset',
                  icon: Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  onTap: () => japa.resetCounter(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats Row ──
          _StatsRow(stats: japa.stats),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Mantra Selector Chips ──

class _MantraSelector extends StatelessWidget {
  final JapaNotifier japa;
  const _MantraSelector({required this.japa});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
              selectedColor: AppColors.saffronLight,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isActive ? AppColors.saffron : AppColors.divider,
              ),
              labelStyle: TextStyle(
                color: isActive ? AppColors.saffron : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Counter Orb ──

class _CounterOrb extends StatelessWidget {
  final int count;
  final int total;
  final double progress;
  final int completedMalas;

  const _CounterOrb({
    required this.count,
    required this.total,
    required this.progress,
    required this.completedMalas,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.62;

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
              valueColor: const AlwaysStoppedAnimation(AppColors.divider),
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
          // Inner tap area
          Container(
            width: size - 32,
            height: size - 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.saffronLight,
                  AppColors.cream,
                ],
                stops: const [0.3, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.saffron.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  'of $total',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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

// ── Action Chip ──

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

// ── Stats Row ──

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

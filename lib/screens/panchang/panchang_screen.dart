import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/panchang_provider.dart';
import '../../widgets/section_card.dart';

class PanchangScreen extends ConsumerWidget {
  const PanchangScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panchang = ref.watch(panchangProvider);

    if (panchang.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = panchang.today;
    if (data == null) {
      return const Center(child: Text('No panchang data available.'));
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(now);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Date Header ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.saffron, AppColors.deepMaroon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Panchang",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.vaar,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── Main Panchang Details ──
          SectionCard(
            title: 'Panchang Details',
            child: Column(
              children: [
                _PanchangRow(
                  icon: Icons.brightness_3_rounded,
                  label: 'Tithi',
                  value: data.tithi,
                  color: AppColors.deepMaroon,
                ),
                const _Divider(),
                _PanchangRow(
                  icon: Icons.star_rounded,
                  label: 'Nakshatra',
                  value: data.nakshatra,
                  color: AppColors.gold,
                ),
                const _Divider(),
                _PanchangRow(
                  icon: Icons.self_improvement_rounded,
                  label: 'Yoga',
                  value: data.yoga,
                  color: AppColors.teal,
                ),
                const _Divider(),
                _PanchangRow(
                  icon: Icons.pie_chart_rounded,
                  label: 'Karana',
                  value: data.karana,
                  color: AppColors.saffron,
                ),
              ],
            ),
          ),

          // ── Sun Times ──
          SectionCard(
            title: 'Sun Timings',
            child: Row(
              children: [
                Expanded(
                  child: _SunTimeCard(
                    icon: Icons.wb_sunny_rounded,
                    label: 'Sunrise',
                    time: data.sunrise,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SunTimeCard(
                    icon: Icons.nights_stay_rounded,
                    label: 'Sunset',
                    time: data.sunset,
                    color: AppColors.deepMaroon,
                  ),
                ),
              ],
            ),
          ),

          // ── Auspicious Note ──
          if (data.auspiciousNote.isNotEmpty)
            SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Note for Today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.auspiciousNote,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
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
}

class _PanchangRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PanchangRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.divider);
  }
}

class _SunTimeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _SunTimeCard({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

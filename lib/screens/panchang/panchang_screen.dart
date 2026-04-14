import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/panchang_data.dart';
import '../../providers/panchang_provider.dart';
import '../../widgets/section_card.dart';

class PanchangScreen extends ConsumerStatefulWidget {
  const PanchangScreen({super.key});

  @override
  ConsumerState<PanchangScreen> createState() => _PanchangScreenState();
}

class _PanchangScreenState extends ConsumerState<PanchangScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final panchang = ref.watch(panchangProvider);

    if (panchang.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final days = panchang.days;
    if (days.isEmpty) {
      return const Center(child: Text('No panchang data available.'));
    }

    final data = days[_selectedIndex];

    return SafeArea(
      child: Column(
        children: [
          // ── Day selector strip ──────────────────────────────────
          _DaySelector(
            days: days,
            selectedIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
          ),

          // ── Scrollable detail area ──────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Date Header card
                _DateHeader(
                  data: data,
                  isToday: _selectedIndex == 0,
                  usingDefault: panchang.usingDefaultLocation,
                ),

                // Panchang Details
                SectionCard(
                  title: 'Panchang Details',
                  child: Column(
                    children: [
                      _PanchangDetailTile(
                        icon: Icons.brightness_3_rounded,
                        label: 'Tithi',
                        value: data.tithi,
                        endTime: data.tithiEndTime,
                        nextValue: data.nextTithi,
                        color: AppColors.deepMaroon,
                      ),
                      const _Divider(),
                      _PanchangDetailTile(
                        icon: Icons.star_rounded,
                        label: 'Nakshatra',
                        value: '${data.nakshatra} (${data.nakshatraPada})',
                        endTime: data.nakshatraEndTime,
                        nextValue: data.nextNakshatra,
                        color: AppColors.gold,
                      ),
                      const _Divider(),
                      _PanchangDetailTile(
                        icon: Icons.self_improvement_rounded,
                        label: 'Yoga',
                        value: data.yoga,
                        endTime: data.yogaEndTime,
                        nextValue: data.nextYoga,
                        color: AppColors.teal,
                      ),
                      const _Divider(),
                      _PanchangDetailTile(
                        icon: Icons.pie_chart_rounded,
                        label: 'Karana',
                        value: data.karana,
                        endTime: data.karanaEndTime,
                        nextValue: data.nextKarana,
                        color: AppColors.saffron,
                      ),
                    ],
                  ),
                ),

                // Sun Timings
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

                // Rahu Kaal
                if (data.rahuKaalStart != null && data.rahuKaalEnd != null)
                  SectionCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rahu Kaal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data.rahuKaalStart} – ${data.rahuKaalEnd}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Zodiac Signs
                SectionCard(
                  title: 'Zodiac Signs',
                  child: Row(
                    children: [
                      Expanded(
                        child: _ZodiacCard(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Sun Sign',
                          value: data.sunSign,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ZodiacCard(
                          icon: Icons.nightlight_round,
                          label: 'Moon Sign',
                          value: data.moonSign,
                          color: AppColors.deepMaroon,
                        ),
                      ),
                    ],
                  ),
                ),

                // Auspicious Note
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
                              Text(
                                _selectedIndex == 0 ? 'Note for Today' : 'Note',
                                style: const TextStyle(
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
          ),
        ],
      ),
    );
  }
}

// ─── Day Selector Strip ─────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  final List<PanchangData> days;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _DaySelector({
    required this.days,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: AppColors.cream,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: days.length,
        itemBuilder: (context, i) {
          final date = DateTime.parse(days[i].date);
          final isSelected = i == selectedIndex;
          final isToday = i == 0;

          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.saffron, AppColors.deepMaroon],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.divider,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.saffron.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? 'Today' : DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Date Header ────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final PanchangData data;
  final bool isToday;
  final bool usingDefault;

  const _DateHeader({
    required this.data,
    required this.isToday,
    required this.usingDefault,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(data.date);
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(date);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  isToday ? "Today's Panchang" : 'Panchang',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (usingDefault && data.locationLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.white60),
                      const SizedBox(width: 3),
                      Text(
                        data.locationLabel!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
          const SizedBox(height: 4),
          Row(
            children: [
              _HeaderChip(label: data.paksha),
              const SizedBox(width: 8),
              _HeaderChip(label: data.moonPhase),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PanchangDetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? endTime;
  final String? nextValue;
  final Color color;

  const _PanchangDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.endTime,
    this.nextValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (endTime != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        'upto $endTime',
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (nextValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    nextValue!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
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

class _ZodiacCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ZodiacCard({
    required this.icon,
    required this.label,
    required this.value,
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
          Icon(icon, size: 22, color: color),
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
                value,
                style: TextStyle(
                  fontSize: 15,
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

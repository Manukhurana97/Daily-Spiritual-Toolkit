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

class _PanchangScreenState extends ConsumerState<PanchangScreen> with WidgetsBindingObserver{
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifeCycleState(AppLifecycleListener state) {
    if(state == AppLifecycleState.resumed) {
      ref.read(panchangProvider).refreshIfNeeded();
    }
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  tier: data.accuracyTier,
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
                        isDark: isDark,
                      ),
                      const _Divider(),
                      _PanchangDetailTile(
                        icon: Icons.star_rounded,
                        label: 'Nakshatra',
                        value: '${data.nakshatra} (${data.nakshatraPada})',
                        endTime: data.nakshatraEndTime,
                        nextValue: data.nextNakshatra,
                        color: AppColors.gold,
                        isDark: isDark,
                      ),
                      const _Divider(),
                      _PanchangDetailTile(
                        icon: Icons.self_improvement_rounded,
                        label: 'Yoga',
                        value: data.yoga,
                        endTime: data.yogaEndTime,
                        nextValue: data.nextYoga,
                        color: AppColors.teal,
                        isDark: isDark,
                      ),
                      const _Divider(),
                      _PanchangDetailTile(
                        icon: Icons.pie_chart_rounded,
                        label: 'Karana',
                        value: data.karana,
                        endTime: data.karanaEndTime,
                        nextValue: data.nextKarana,
                        color: AppColors.saffron,
                        isDark: isDark,
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
                            color: isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: isDark ? Colors.red.shade300 :  Colors.red.shade700,
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
                                  color: isDark ? Colors.red.shade300 :  Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data.rahuKaalStart} – ${data.rahuKaalEnd}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ?  AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Gulika Kaal
                if (data.gulikaKaalStart != null && data.gulikaKaalEnd != null)
                  SectionCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.do_not_disturb_on_outlined,
                              color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gulika kaal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${data.gulikaKaalStart} - ${data.gulikaKaalEnd}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  )
                                ],
                              )
                          )
                        ],
                      ),
                  ),

                // Abhijit Muhurta
                if (data.abhijitMahurtaStart != null && data.abhijitMahurtaEnd != null)
                  SectionCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Abhijit Mahurta',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${data.abhijitMahurtaStart} - ${data.abhijitMahurtaEnd}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Always auspicious - ideal for important activities',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  )
                                ],
                              )
                          )
                        ],
                      )
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
                            color: isDark ? AppColors.teal.withValues(alpha: 0.15) : AppColors.tealLight,
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 72,
      color: isDark ? AppColors.darkSurface :  AppColors.cream,
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
                color: isSelected ? null : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : (isDark ? AppColors.darkDivider : AppColors.divider),
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
                      color: isSelected ? Colors.white70 : (isDark ?  AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
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
  final LocationTier tier;

  const _DateHeader({
    required this.data,
    required this.isToday,
    required this.tier,
  });

  void _showAccuracyInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String tierLabel;
    String tierDesc;
    String accuracy;
    IconData tierIcon;
    Color tierColor;

    switch (tier) {
      case LocationTier.gps:
        tierLabel = 'GPS Location';
        tierDesc = 'Using your device\'s precise GPS coordinates and altitude.';
        accuracy = '±5-15 seconds';
        tierIcon = Icons.gps_fixed;
        tierColor = Colors.green;
        break;
      case LocationTier.ip:
        tierLabel = 'IP-Based Location';
        tierDesc = 'GPS was unavailable. Using approximate location from your internet connection (city-level).';
        accuracy = '±1-3 minutes';
        tierIcon = Icons.wifi;
        tierColor = Colors.orange;
        break;
      case LocationTier.fallback:
        tierLabel = 'Default Location (New Delhi)';
        tierDesc = 'Could not determine your location. Showing panchang for New Delhi. Enable location access for accurate results';
        accuracy = 'May differ significantly';
        tierIcon = Icons.location_off;
        tierColor = Colors.red;
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                Icon(tierIcon, color: tierColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Panchang Accuracy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AccuracyInfoRow(
              label: 'Location Source',
              value: tierLabel,
              valueColor: tierColor,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _AccuracyInfoRow(
              label: 'Time Accuracy',
              value: tierLabel,
              valueColor: tierColor,
              isDark: isDark,
            ),
            if (data.locationLabel != null) ...[
              const SizedBox(height: 8),
              _AccuracyInfoRow(
                label: 'Location',
                value: data.locationLabel!,
                isDark: isDark,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              tierDesc,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.4
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Powered by Swiss Ephemeris',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Same astronomical engine used by professional astrologers worldwide. '
                        'Lahiri Ayanamsa (Indian national standard). '
                        'Moon parallax correction for your exact position.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      height: 1.4,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

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
              // Location clip
              if (data.locationLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
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

              // Accuracy info button
              GestureDetector(
                onTap: () => _showAccuracyInfo(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: tier == LocationTier.gps
                      ? Colors.greenAccent.shade100
                        : tier == LocationTier.ip
                      ? Colors.orangeAccent.shade100
                        : Colors.redAccent.shade100,
                  ),
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

class _AccuracyInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  const _AccuracyInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        )
      ],
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
  final bool isDark;

  const _PanchangDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.endTime,
    this.nextValue,
    required this.color,
    required this.isDark,
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
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                    'then $nextValue',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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

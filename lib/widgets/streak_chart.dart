import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../database/app_database.dart';

class StreakChart extends StatelessWidget {
  final List<DailyCount> data;
  final int streak;

  const StreakChart({super.key, required this.data, required this.streak});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxCount = data.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final maxY = (maxCount > 0 ? maxCount * 1.3 : 100).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department_rounded,
                size: 20,
                color: streak > 0 ? AppColors.saffron : AppColors.textSecondary
            ),
            const SizedBox(width: 6),
            Text(
              streak > 0 ?'$streak day${streak != 1 ? 's' : ''} streak' : 'No streak yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: streak > 0
                    ? AppColors.saffron :
                (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              ),
            ),
            const Spacer(),
            if (maxCount > 0)
              Text(
                'Best: $maxCount',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} japs',
                      TextStyle(
                          color: isDark
                              ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      final isToday = idx == data.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          isToday ? 'Today' : DateFormat('E').format(data[idx].date).substring(0, 2),
                          style: TextStyle(
                            fontSize: isToday ? 10 : 11,
                            fontWeight: isToday ? FontWeight.w600: FontWeight.w400,
                            color: isToday
                              ? AppColors.saffron
                                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                          )
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: List.generate(data.length, (i) {
                final isToday = i == data.length - 1;
                final hasData = data[i].count > 0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY:  data[i].count > 0 ? data[i].count.toDouble() : maxY * 0.02,
                      gradient: hasData
                        ? LinearGradient(
                          begin : Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isToday
                            ? [AppColors.saffron, AppColors.gold]
                            : [AppColors.teal.withValues(alpha: 0.6), AppColors.teal],
                      )
                      : null,
                      color: isToday ? AppColors.saffron : (isDark ? AppColors.darkDivider : AppColors.divider),
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }),
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
      ],
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/compass_provider.dart';

class CompassScreen extends ConsumerWidget {
  const CompassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compass = ref.watch(compassProvider);

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),

          // ── "Face East" Banner ──
          _DirectionBanner(compass: compass),

          // ── Compass Rose ──
          Expanded(
            child: Center(
              child: compass.heading != null
                  ? _CompassRose(heading: compass.heading!)
                  : _CompassPlaceholder(),
            ),
          ),

          // ── Heading Info ──
          if (compass.heading != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${compass.heading!.toStringAsFixed(0)}° ${compass.cardinalDirectionFull}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

          // ── Calibration Hint ──
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Wave your phone in a figure-8 pattern to calibrate the compass.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionBanner extends StatelessWidget {
  final CompassNotifier compass;
  const _DirectionBanner({required this.compass});

  @override
  Widget build(BuildContext context) {
    final isFacingEast = compass.isFacingEast;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFacingEast
              ? [AppColors.teal, const Color(0xFF00695C)]
              : [AppColors.saffron, AppColors.deepMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isFacingEast ? Icons.check_circle_rounded : Icons.east_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFacingEast ? 'You are facing East' : 'Face East for Puja',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFacingEast
                      ? 'Ideal direction for Sun worship & general puja.'
                      : 'Rotate to face East for Sun worship & general puja.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

class _CompassRose extends StatelessWidget {
  final double heading;
  const _CompassRose({required this.heading});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CompassPainter(heading: heading),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double heading;
  const _CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final angle = -heading * pi / 180;

    // Outer ring
    final outerPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerPaint);

    // Inner subtle ring
    final innerPaint = Paint()
      ..color = AppColors.saffronLight
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 8, innerPaint);

    final innerBorderPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 8, innerBorderPaint);

    // Tick marks
    for (int i = 0; i < 72; i++) {
      final tickAngle = angle + i * (2 * pi / 72);
      final isMajor = i % 18 == 0;
      final isMinor = i % 9 == 0;

      final startR = isMajor ? radius - 24 : (isMinor ? radius - 18 : radius - 14);
      final endR = radius - 8;

      final start = Offset(
        center.dx + startR * sin(tickAngle),
        center.dy - startR * cos(tickAngle),
      );
      final end = Offset(
        center.dx + endR * sin(tickAngle),
        center.dy - endR * cos(tickAngle),
      );

      final tickPaint = Paint()
        ..color = isMajor ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.4)
        ..strokeWidth = isMajor ? 2.5 : 1;

      canvas.drawLine(start, end, tickPaint);
    }

    // Cardinal labels
    final directions = ['N', 'E', 'S', 'W'];
    final dirAngles = [0.0, pi / 2, pi, 3 * pi / 2];
    final dirColors = [
      const Color(0xFFD32F2F), // N = red
      AppColors.saffron,       // E = saffron (puja direction)
      AppColors.textSecondary,
      AppColors.textSecondary,
    ];

    for (int i = 0; i < 4; i++) {
      final dirAngle = angle + dirAngles[i];
      final labelR = radius - 40;
      final pos = Offset(
        center.dx + labelR * sin(dirAngle),
        center.dy - labelR * cos(dirAngle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: dirColors[i],
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }

    // Needle (points to top = device heading direction)
    final needleLength = radius - 52;

    // North needle (top)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - needleLength)
      ..lineTo(center.dx - 8, center.dy)
      ..lineTo(center.dx + 8, center.dy)
      ..close();

    canvas.drawPath(
      northPath,
      Paint()..color = const Color(0xFFD32F2F),
    );

    // South needle (bottom)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + needleLength)
      ..lineTo(center.dx - 8, center.dy)
      ..lineTo(center.dx + 8, center.dy)
      ..close();

    canvas.drawPath(
      southPath,
      Paint()..color = AppColors.textSecondary.withValues(alpha: 0.3),
    );

    // Center dot
    canvas.drawCircle(
      center,
      6,
      Paint()..color = AppColors.textPrimary,
    );
    canvas.drawCircle(
      center,
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter oldDelegate) =>
      oldDelegate.heading != heading;
}

class _CompassPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.explore_off_rounded,
          size: 64,
          color: AppColors.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'Compass sensor not available',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'This device may not have a magnetometer.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

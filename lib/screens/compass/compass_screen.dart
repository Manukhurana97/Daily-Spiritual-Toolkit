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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Mode toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: _DirectionBanner(compass: compass, isDark: isDark)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => compass.toggleSpiritualMode(),
                      icon: Icon(
                        compass.spiritualMode ? Icons.temple_hindu : Icons.explore_rounded,
                        color: compass.spiritualMode ? AppColors.gold : AppColors.textSecondary,
                      ),
                      tooltip: compass.spiritualMode ? 'Basic Mode' : 'Spiritual Mode',
                    ),
                  ],
                ),
              ),

              // Ishan Kon banner
              if (compass.spiritualMode && compass.isFacingNorthEast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ishan Kon (NE) — most auspicious direction for puja room',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: Center(
                  child: compass.heading != null
                      ? _CompassRose(
                          heading: compass.heading!,
                          isDark: isDark,
                          showIshan: compass.spiritualMode,
                          pilgrimBearings: compass.spiritualMode
                              ? CompassNotifier.pilgrimages
                                  .map((p) => _PilgrimLabel(p.name, compass.bearingTo(p)))
                                  .where((p) => p.bearing != null)
                                  .toList()
                              : [],
                        )
                      : _CompassPlaceholder(isDark: isDark),
                ),
              ),

              if (compass.heading != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${compass.heading!.toStringAsFixed(0)}° ${compass.cardinalDirectionFull}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),

              // Low accuracy warning banner
              if (compass.isLowAccuracy)
                Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                'Low accuracy - move phone in figure-8 to calibrate',
                                style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                              ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(width: 24, height: 24, child: _Figure8Animation()),
                        ],
                      ),
                    ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.teal.withValues(alpha: 0.15) : AppColors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          compass.spiritualMode
                              ? 'Spiritual mode active — pilgrimage sites and Ishan Kon visible.'
                              : compass.isLowAccuracy
                              ? 'Low accuracy detected - Wave your phone in a figure-8 pattern to calibrate.'
                          : 'Compass is working. Tap the icon above for spiritual mode.',
                          style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (compass.needCalibrationHind)
          _CalibrationOverlay(onDismiss: () => compass.dismissCalibration()),
      ],
    );
  }
}

class _PilgrimLabel {
  final String name;
  final double? bearing;
  _PilgrimLabel(this.name, this.bearing);
}

class _DirectionBanner extends StatelessWidget {
  final CompassNotifier compass;
  final bool isDark;
  const _DirectionBanner({required this.compass, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isFacingEast = compass.isFacingEast;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFacingEast ? 'Facing East' : 'Face East for Puja',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  isFacingEast
                      ? 'Ideal for Sun worship & puja.'
                      : 'Rotate to face East.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
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
  final bool isDark;
  final bool showIshan;
  final List<_PilgrimLabel> pilgrimBearings;

  const _CompassRose({
    required this.heading,
    required this.isDark,
    this.showIshan = false,
    this.pilgrimBearings = const [],
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CompassPainter(
          heading: heading,
          isDark: isDark,
          showIshan: showIshan,
          pilgrimBearings: pilgrimBearings,
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double heading;
  final bool isDark;
  final bool showIshan;
  final List<_PilgrimLabel> pilgrimBearings;

  const _CompassPainter({
    required this.heading,
    required this.isDark,
    required this.showIshan,
    this.pilgrimBearings = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final angle = -heading * pi / 180;

    final bgColor = isDark ? AppColors.darkCard : AppColors.saffronLight;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    // Ishan Kon wedge (NE highlight)
    if (showIshan) {
      final ishanAngle = angle + pi / 4;
      final wedgePath = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius - 8),
          ishanAngle - pi / 12 - pi / 2,
          pi / 6,
          false,
        )
        ..close();
      canvas.drawPath(wedgePath, Paint()..color = AppColors.gold.withValues(alpha: 0.15));
    }

    // Outer ring
    canvas.drawCircle(center, radius, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 2);

    // Inner ring
    canvas.drawCircle(center, radius - 8, Paint()..color = bgColor..style = PaintingStyle.fill);
    canvas.drawCircle(center, radius - 8, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1);

    // Tick marks
    for (int i = 0; i < 72; i++) {
      final tickAngle = angle + i * (2 * pi / 72);
      final isMajor = i % 18 == 0;
      final isMinor = i % 9 == 0;
      final startR = isMajor ? radius - 24 : (isMinor ? radius - 18 : radius - 14);
      final endR = radius - 8;

      final startOff = Offset(center.dx + startR * sin(tickAngle), center.dy - startR * cos(tickAngle));
      final endOff = Offset(center.dx + endR * sin(tickAngle), center.dy - endR * cos(tickAngle));

      canvas.drawLine(startOff, endOff, Paint()
        ..color = isMajor ? textPrimary : textSecondary.withValues(alpha: 0.4)
        ..strokeWidth = isMajor ? 2.5 : 1);
    }

    // Cardinal labels
    final directions = ['N', 'E', 'S', 'W'];
    final dirAngles = [0.0, pi / 2, pi, 3 * pi / 2];
    final dirColors = [const Color(0xFFD32F2F), AppColors.saffron, textSecondary, textSecondary];

    for (int i = 0; i < 4; i++) {
      final dirAngle = angle + dirAngles[i];
      final labelR = radius - 40;
      final pos = Offset(center.dx + labelR * sin(dirAngle), center.dy - labelR * cos(dirAngle));

      final tp = TextPainter(
        text: TextSpan(text: directions[i], style: TextStyle(color: dirColors[i], fontSize: 18, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    // Pilgrimage site labels
    for (final p in pilgrimBearings) {
      if (p.bearing == null) continue;
      final pAngle = angle + p.bearing! * pi / 180;
      final pR = radius + 6;
      final pos = Offset(center.dx + pR * sin(pAngle), center.dy - pR * cos(pAngle));

      final dot = Paint()..color = AppColors.gold;
      canvas.drawCircle(pos, 4, dot);

      final tp = TextPainter(
        text: TextSpan(text: p.name, style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 5));
    }

    // Needle
    final needleLength = radius - 52;
    final northPath = Path()
      ..moveTo(center.dx, center.dy - needleLength)
      ..lineTo(center.dx - 8, center.dy)
      ..lineTo(center.dx + 8, center.dy)
      ..close();
    canvas.drawPath(northPath, Paint()..color = const Color(0xFFD32F2F));

    final southPath = Path()
      ..moveTo(center.dx, center.dy + needleLength)
      ..lineTo(center.dx - 8, center.dy)
      ..lineTo(center.dx + 8, center.dy)
      ..close();
    canvas.drawPath(southPath, Paint()..color = textSecondary.withValues(alpha: 0.3));

    // Center dot
    canvas.drawCircle(center, 6, Paint()..color = textPrimary);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.heading != heading || old.isDark != isDark || old.showIshan != showIshan;
}

class _CompassPlaceholder extends StatelessWidget {
  final bool isDark;
  const _CompassPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.explore_off_rounded, size: 64, color: color.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text('Compass sensor not available', style: TextStyle(fontSize: 16, color: color)),
        const SizedBox(height: 4),
        Text('This device may not have a magnetometer.', style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

class _CalibrationOverlay extends StatelessWidget {
  final VoidCallback onDismiss;
  const _CalibrationOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.gold),
            const SizedBox(height: 16),
            const Text('Compass Needs Calibration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Move your phone slowly in a figure-8 / infinity pattern until the compass stabilises.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(width: 180, height: 100, child: _Figure8Animation()),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: onDismiss,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Dismiss', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure8Animation extends StatefulWidget {
  const _Figure8Animation();
  @override
  State<_Figure8Animation> createState() => _Figure8AnimationState();
}

class _Figure8AnimationState extends State<_Figure8Animation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(painter: _Figure8Painter(progress: _controller.value), size: const Size(180, 100)),
    );
  }
}

class _Figure8Painter extends CustomPainter {
  final double progress;
  _Figure8Painter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final rx = size.width * 0.38, ry = size.height * 0.38;

    final path = Path();
    for (var i = 0; i <= 200; i++) {
      final t = i / 200 * 2 * pi;
      final x = cx + rx * cos(t) / (1 + sin(t) * sin(t));
      final y = cy + ry * sin(t) * cos(t) / (1 + sin(t) * sin(t));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2.5);

    final t = progress * 2 * pi;
    final dotX = cx + rx * cos(t) / (1 + sin(t) * sin(t));
    final dotY = cy + ry * sin(t) * cos(t) / (1 + sin(t) * sin(t));
    canvas.drawCircle(Offset(dotX, dotY), 7, Paint()..color = AppColors.gold);
    canvas.drawCircle(Offset(dotX, dotY), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _Figure8Painter old) => old.progress != progress;
}

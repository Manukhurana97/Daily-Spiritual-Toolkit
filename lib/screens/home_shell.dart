import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../widgets/section_card.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _mantras = <String>['Radha', 'Ram', 'Krishna'];
  static const _tapCooldownMs = 300;
  static const _roundTarget = 108;
  static const _prefsKey = 'japa_state_by_mantra_v1';

  late String _selectedMantra;
  final Map<String, _MantraState> _stateByMantra = <String, _MantraState>{};
  DateTime? _lastTapAt;
  bool _ready = false;

  _MantraState get _activeState => _stateByMantra[_selectedMantra] ?? const _MantraState();

  @override
  void initState() {
    super.initState();
    _selectedMantra = _mantras.first;
    for (final mantra in _mantras) {
      _stateByMantra[mantra] = const _MantraState();
    }
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (_stateByMantra.containsKey(entry.key)) {
          _stateByMantra[entry.key] = _MantraState.fromMap(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        _ready = true;
      });
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      for (final entry in _stateByMantra.entries) entry.key: entry.value.toMap(),
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  void _countTap() {
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < _tapCooldownMs) {
      return;
    }
    _lastTapAt = now;

    final current = _activeState;
    var nextRoundProgress = current.roundProgress + 1;
    var roundsCompleted = current.roundsCompleted;
    if (nextRoundProgress > _roundTarget) {
      nextRoundProgress = 1;
      roundsCompleted += 1;
    }

    setState(() {
      _stateByMantra[_selectedMantra] = current.copyWith(
        roundProgress: nextRoundProgress,
        totalCount: current.totalCount + 1,
        roundsCompleted: roundsCompleted,
        lastTappedAtIso: now.toIso8601String(),
      );
    });
    _persistState();
  }

  void _resetActiveMantra() {
    final current = _activeState;
    setState(() {
      _stateByMantra[_selectedMantra] = current.copyWith(
        roundProgress: 0,
        roundsCompleted: 0,
        totalCount: 0,
        lastTappedAtIso: null,
      );
    });
    _persistState();
  }

  @override
  Widget build(BuildContext context) {
    final state = _activeState;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Naam Jap'),
        actions: [
          IconButton(
            onPressed: _resetActiveMantra,
            tooltip: 'Reset selected mantra',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 22),
                children: [
                  SectionCard(
                    title: 'Choose Mantra',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _mantras
                          .map(
                            (mantra) => ChoiceChip(
                              label: Text(mantra),
                              selected: mantra == _selectedMantra,
                              onSelected: (_) {
                                setState(() {
                                  _selectedMantra = mantra;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SectionCard(
                    title: '$_selectedMantra Jaap',
                    child: Column(
                      children: [
                        Text(
                          '${state.roundProgress} / $_roundTarget',
                          style: textTheme.headlineMedium?.copyWith(
                            color: AppColors.deepMaroon,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _MalaBeadRing(progress: state.roundProgress, total: _roundTarget),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: ElevatedButton(
                            onPressed: _countTap,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: AppColors.saffron,
                              foregroundColor: Colors.white,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app_rounded, size: 36),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap For $_selectedMantra Naam',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Progress stays separate for each mantra.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SectionCard(
                    title: 'Stats',
                    child: Row(
                      children: [
                        _StatItem(label: 'Total', value: '${state.totalCount}'),
                        const SizedBox(width: 12),
                        _StatItem(label: 'Rounds', value: '${state.roundsCompleted}'),
                        const SizedBox(width: 12),
                        _StatItem(
                          label: 'Last Tap',
                          value: state.lastTappedAtIso == null ? '-' : 'Saved',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MalaBeadRing extends StatelessWidget {
  const _MalaBeadRing({
    required this.progress,
    required this.total,
  });

  final int progress;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: _BeadRingPainter(progress: progress, total: total),
      ),
    );
  }
}

class _BeadRingPainter extends CustomPainter {
  _BeadRingPainter({
    required this.progress,
    required this.total,
  });

  final int progress;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width / 2 - 10;

    for (var i = 0; i < total; i++) {
      final isDone = i < progress;
      final angle = (2 * math.pi * i / total) - math.pi / 2;
      final beadCenter = Offset(
        center.dx + ringRadius * math.cos(angle),
        center.dy + ringRadius * math.sin(angle),
      );

      final paint = Paint()
        ..color = isDone ? AppColors.saffron : const Color(0xFFF1DFC8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(beadCenter, isDone ? 4.4 : 3.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeadRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.total != total;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.saffronLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MantraState {
  const _MantraState({
    this.roundProgress = 0,
    this.totalCount = 0,
    this.roundsCompleted = 0,
    this.lastTappedAtIso,
  });

  final int roundProgress;
  final int totalCount;
  final int roundsCompleted;
  final String? lastTappedAtIso;

  _MantraState copyWith({
    int? roundProgress,
    int? totalCount,
    int? roundsCompleted,
    String? lastTappedAtIso,
  }) {
    return _MantraState(
      roundProgress: roundProgress ?? this.roundProgress,
      totalCount: totalCount ?? this.totalCount,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      lastTappedAtIso: lastTappedAtIso,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'roundProgress': roundProgress,
      'totalCount': totalCount,
      'roundsCompleted': roundsCompleted,
      'lastTappedAtIso': lastTappedAtIso,
    };
  }

  factory _MantraState.fromMap(Map<String, dynamic> map) {
    return _MantraState(
      roundProgress: (map['roundProgress'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
      roundsCompleted: (map['roundsCompleted'] as num?)?.toInt() ?? 0,
      lastTappedAtIso: map['lastTappedAtIso'] as String?,
    );
  }
}

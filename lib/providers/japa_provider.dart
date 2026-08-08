import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/constants/app_constants.dart';
import '../database/app_database.dart';
import '../models/mantra.dart';
import '../models/japa_session.dart';
import '../models/japa_stats.dart';

final japaProvider = ChangeNotifierProvider<JapaNotifier>((ref) {
  return JapaNotifier();
});

class _MantraSessionState {
  int count;
  DateTime? sessionStart;
  DateTime? lastTapTime;

  _MantraSessionState({this.count = 0, this.sessionStart, this.lastTapTime});
}

class JapaNotifier extends ChangeNotifier {
  List<Mantra> _mantras = [];
  Mantra? _activeMantra;
  int _currentCount = 0;
  DateTime? _sessionStart;
  DateTime? _lastTapTime;
  JapaStats _stats = JapaStats.empty;
  bool _isLoading = true;

  final Map<int, _MantraSessionState> _suspendedSessions = {};

  // Anti-span state
  static const _botWindowSize = 12;
  static const _hardFloorMs = 150;
  static const _botCvThreshold = 0.05;
  final List<int> _recentIntervals = [];
  DateTime? _cooldownUnit;


  List<Mantra> get mantras => _mantras;
  Mantra? get activeMantra => _activeMantra;
  int get currentCount => _currentCount;
  JapaStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get hasSession => _sessionStart != null && _currentCount > 0;

  int _malaSize = AppConstants.defaultMalaSize;
  int _dailyGoal = 0;

  int get malaSize => _malaSize;
  int get dailyGoal => _dailyGoal;
  int get currentMalaProgress => _currentCount % _malaSize;
  int get completedMala => _currentCount ~/ _malaSize;

  void updateTargets({required int malaSize, required int dailyGoal}) {
    _malaSize = malaSize;
    _dailyGoal = dailyGoal;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _mantras = await AppDatabase.getMantras();

    if (_mantras.isEmpty) {
      for (final name in AppConstants.defaultMantras) {
        final m = await AppDatabase.insertMantra(name);
        _mantras.add(m);
      }
    }

    _activeMantra = _mantras.first;
    await _refreshStats();

    _isLoading = false;
    notifyListeners();
  }

  void selectMantra(Mantra mantra) {
    if (_activeMantra == mantra) return;

    // Persist adaptive stats for outgoing mantra
    _presistAdaptiveStats();

    if (_activeMantra != null && hasSession) {
      _suspendedSessions[_activeMantra!.id!] = _MantraSessionState(
        count: _currentCount,
        sessionStart: _sessionStart,
        lastTapTime: _lastTapTime,
      );
    }

    _activeMantra = mantra;

    // Reset anti-span sliding window on mantra switch
    _recentIntervals.clear();
    _cooldownUnit = null;

    final restored = _suspendedSessions.remove(mantra.id!);
    if (restored != null) {
      _currentCount = restored.count;
      _sessionStart = restored.sessionStart;
      _lastTapTime = restored.lastTapTime;
    } else {
      _currentCount = 0;
      _sessionStart = null;
      _lastTapTime = null;
    }

    _refreshStats();
    notifyListeners();
  }

  /// Returns true if the tap was accepted, false if throttled.
  /// Three-layer anti-spam
  /// 1. Auto-clicker patterns detection (CV of recent internals)
  /// 2. Uses-configuration speed override (pre mantra)
  /// 3. Adaptive EMA threshold (learn uses's pace over time)
  bool tap() {
    final now = DateTime.now();

    // Layer 0: bot cooldown active
    if (_cooldownUnit != null) {
      if (now.isBefore(_cooldownUnit!)) return false;
      _cooldownUnit = null;
    }

    if (_lastTapTime != null) {
     final intervalMs = now.difference(_lastTapTime!).inMilliseconds;
     if (intervalMs < _hardFloorMs) return false;

     if (intervalMs > 5000) _recentIntervals.clear();

     final thrashold = _getSpeedThreshold();
     if (intervalMs < thrashold) return false;

     _recentIntervals.add(intervalMs);
     if (_recentIntervals.length > _botWindowSize) {
       _recentIntervals.removeAt(0);
     }

     if(_isAutoClicker()) {
       _cooldownUnit = now.add(const Duration(seconds: 3));
       _recentIntervals.clear();
       return false;
     }
    }

    _sessionStart ??= now;
    final prevTap = _lastTapTime;
    _lastTapTime = now;
    _currentCount++;

    if (prevTap != null) {
      _updateAdaptiveStats(now.difference(prevTap).inMilliseconds);
    }

    notifyListeners();
    return true;
  }

  bool _isAutoClicker() {
    if (_recentIntervals.length < 6) return false;
    final recent = _recentIntervals.sublist(max(0, _recentIntervals.length - 8));
    final n = recent.length;
    final mean = recent.reduce((a, b) => a + b) / n;
    if (mean <= 0) return false;
    double sumSqDiff = 0;
    for (final i in recent) {
      sumSqDiff += (i - mean) * (i - mean);
    }
    final stdDev = sqrt(sumSqDiff / n);
    return (stdDev / mean) < _botCvThreshold;
  }

  int _getSpeedThreshold() {
    if (_activeMantra == null) return 200;

    final userSpeed = _activeMantra!.tapSpeedMs;
    if (userSpeed != null) return userSpeed;

    final avgMs = _activeMantra!.avgTapMs;
    final samples = activeMantra!.tapSampleCount;
    if (avgMs != null && samples >= 30) {
      return (avgMs * 0.6).round().clamp(_hardFloorMs, 3000);
    }

    return 200;
  }

  void _updateAdaptiveStats(int intervalMs) {
    if (_activeMantra == null) return;
    if (intervalMs > 10000 || intervalMs < _hardFloorMs) return;

    final mantra = _activeMantra!;
    final oldAvg = mantra.avgTapMs ?? intervalMs.toDouble();
    final oldCount = mantra.tapSampleCount;

    final double newAvg;
    if (oldCount < 10) {
      newAvg = (oldAvg * oldCount + intervalMs) / (oldCount + 1);
    } else {
      const alpha = 0.05;
      newAvg = oldAvg * (1 - alpha) + intervalMs * alpha;
    }
    final newCount = oldCount + 1;

    final updated = mantra.copyWith(
      avgTapMS: newAvg,
      tapSampleCount: newCount,
    );

    final idx = _mantras.indexWhere((m) => m.id == mantra.id);
    if (idx != -1) _mantras[idx] = updated;
    _activeMantra = updated;

    if (newCount % 10 == 0) {
      AppDatabase.updateMantraAdaptiveStats(mantra.id!, newAvg, newCount);
    }
  }

  void _presistAdaptiveStats() {
    final mantra = _activeMantra;
    if (mantra?.id == null || mantra!.tapSampleCount == 0) return;
    AppDatabase.updateMantraAdaptiveStats(mantra.id!, mantra.avgTapMs ?? 0, mantra.tapSampleCount);
  }

  Future<void> resetCounter() async {
    _currentCount = 0;
    _sessionStart = null;
    _lastTapTime = null;
    _recentIntervals.clear();
    _cooldownUnit = null;
    notifyListeners();
  }

  Future<void> endSession() async {
    if (hasSession) {
      _presistAdaptiveStats();
      await _saveCurrentSession();
      _currentCount = 0;
      _sessionStart = null;
      _lastTapTime = null;
      _recentIntervals.clear();
      _cooldownUnit = null;
      await _refreshStats();
      notifyListeners();
    }
  }

  Future<bool> addMantra(
      String name, {
        String? actualMantra,
        String? targetDirection,
        String activeDays = 'all',
        String bestTime = 'anytime',
      }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final max = AppConstants.maxMantras;
    if (_mantras.length >= max) return false;
    final mantra = await AppDatabase.insertMantra(
      trimmed,
      actualMantra: actualMantra?.trim(),
      targetDirection: targetDirection?.trim(),
      activeDays: activeDays,
      bestTime: bestTime
    );
    _mantras.add(mantra);
    notifyListeners();
    return true;
  }

  Future<void> updateMantraDetails(Mantra mantra) async {
    await AppDatabase.updateMantraFull(mantra);
    final idx = _mantras.indexWhere((m) => m.id == mantra.id);
    if (idx != -1) {
      _mantras[idx] = mantra;
      if (_activeMantra?.id == mantra.id) {
        _activeMantra = mantra;
      }
    }
    notifyListeners();
  }

  Future<void> removeMantra(Mantra mantra) async {
    if (_mantras.length <= 1) return;
    await AppDatabase.deleteMantra(mantra.id!);
    _mantras.remove(mantra);
    _suspendedSessions.remove(mantra.id!);
    if (_activeMantra == mantra) {
      _activeMantra = _mantras.first;
      _currentCount = 0;
      _sessionStart = null;
      await _refreshStats();
    }
    notifyListeners();
  }

  Future<void> resetAll() async {
    await AppDatabase.resetAll();
    _mantras.clear();
    _activeMantra = null;
    _currentCount = 0;
    _sessionStart = null;
    _lastTapTime = null;
    _recentIntervals.clear();
    _cooldownUnit = null;
    _suspendedSessions.clear();
    _stats = JapaStats.empty;
    await initialize();
  }

  Future<void> renameMantra(Mantra mantra, String newName) async {
    await AppDatabase.updateMantra(mantra.id!, newName);
    final idx = _mantras.indexWhere((m) => m.id == mantra.id);
    if (idx != -1) {
      _mantras[idx] = mantra.copyWith(name: newName);
      if (_activeMantra?.id == mantra.id) {
        _activeMantra = _mantras[idx];
      }
    }
    notifyListeners();
  }

  Future<void> _saveCurrentSession() async {
    if (_activeMantra == null || _currentCount == 0 || _sessionStart == null) return;

    final session = JapaSession(
      mantraId: _activeMantra!.id!,
      count: _currentCount,
      startedAt: _sessionStart!,
      endedAt: DateTime.now(),
    );
    await AppDatabase.insertSession(session);
    await _refreshStats();
  }

  Future<void> _refreshStats() async {
    if (_activeMantra == null) return;

    final mantraId = _activeMantra!.id!;
    final todayCount = await AppDatabase.getTodayCount(mantraId);
    final totalCount = await AppDatabase.getTotalCount(mantraId);
    final lastRow = await AppDatabase.getLastSession(mantraId);

    LastSessionInfo? lastSession;
    if (lastRow != null) {
      final s = JapaSession.fromMap(lastRow);
      lastSession = LastSessionInfo(
        count: s.count,
        duration: s.duration,
        endedAt: s.endedAt,
      );
    }

    _stats = JapaStats(
      todayCount: todayCount,
      totalCount: totalCount,
      todayMalas: todayCount ~/ malaSize,
      totalMalas: totalCount ~/ malaSize,
      lastSession: lastSession,
    );
    notifyListeners();
  }
}

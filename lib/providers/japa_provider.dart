import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  List<Mantra> get mantras => _mantras;
  Mantra? get activeMantra => _activeMantra;
  int get currentCount => _currentCount;
  JapaStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get hasSession => _sessionStart != null && _currentCount > 0;

  int get currentMalaProgress => _currentCount % AppConstants.malaSize;
  int get completedMalas => _currentCount ~/ AppConstants.malaSize;

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

    if (_activeMantra != null && hasSession) {
      _suspendedSessions[_activeMantra!.id!] = _MantraSessionState(
        count: _currentCount,
        sessionStart: _sessionStart,
        lastTapTime: _lastTapTime,
      );
    }

    _activeMantra = mantra;

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
  bool tap() {
    final now = DateTime.now();

    if (_lastTapTime != null) {
      final elapsed = now.difference(_lastTapTime!);
      if (elapsed < AppConstants.antiSpamInterval) {
        return false;
      }
    }

    _sessionStart ??= now;
    _lastTapTime = now;
    _currentCount++;
    notifyListeners();

    return true;
  }

  Future<void> resetCounter() async {
    _currentCount = 0;
    _sessionStart = null;
    _lastTapTime = null;
    notifyListeners();
  }

  Future<void> endSession() async {
    if (hasSession) {
      await _saveCurrentSession();
      _currentCount = 0;
      _sessionStart = null;
      _lastTapTime = null;
      await _refreshStats();
      notifyListeners();
    }
  }

  Future<void> addMantra(String name) async {
    final max = AppConstants.maxMantras;
    if (_mantras.length >= max) return;
    final mantra = await AppDatabase.insertMantra(name);
    _mantras.add(mantra);
    notifyListeners();
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
      todayMalas: todayCount ~/ AppConstants.malaSize,
      totalMalas: totalCount ~/ AppConstants.malaSize,
      lastSession: lastSession,
    );
    notifyListeners();
  }
}

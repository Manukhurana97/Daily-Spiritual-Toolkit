import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/app_database.dart';
import '../models/sankalp.dart';
import '../services/sankalp_engine.dart';

final sankalpProvider = ChangeNotifierProvider<SankalpNotifier>((ref) {
  return SankalpNotifier();
});

class SankalpNotifier extends ChangeNotifier {
  SankalpEngine? _engine;
  Sankalp? _activeSankalp;
  bool _isLoading = false;
  List<Sankalp> _history = [];
  Set<int> _sankalpMantraIds = {};

  SankalpEngine? get engine => _engine;
  Sankalp? get activeSankalp => _activeSankalp;
  bool get isLoading => _isLoading;
  bool get hasActiveSankalp => _activeSankalp != null && !(_engine?.isComplete ?? false);
  List<Sankalp> get hisotry => _history;
  Set<int> get sankalpMantraIds => _sankalpMantraIds;

  bool mantraHasSankalp(int mantraId) => _sankalpMantraIds.contains(mantraId);

  Future<void> loadForMantra(int mantraId) async {
    _isLoading = true;
    notifyListeners();

    _activeSankalp = await AppDatabase.getActiveSankalp(mantraId);
    if (_activeSankalp != null) {
      final count = await AppDatabase.getCountSinceDate(
        mantraId,
        _activeSankalp!.startDate,
      );
      final todayCount = await AppDatabase.getCountForDate(mantraId, DateTime.now());
      _engine = SankalpEngine(sankalp: _activeSankalp!, completedCount: count, todayCount: todayCount);

      if (_engine!.isComplete && _activeSankalp!.completedAt == null) {
        await AppDatabase.completeSankalp(_activeSankalp!.id!);
        _activeSankalp = _activeSankalp!.copyWith(completedAt: DateTime.now());
      }
    } else {
      _engine = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _history = await AppDatabase.getSankalpHistory();
    notifyListeners();
  }

  Future<void> loadSankalpMantraIds(List<int> mantraIds) async {
    final ids = <int>{};
    for (final id in mantraIds) {
      if (await AppDatabase.hasActiveSankalpForMantra(id)) {
        ids.add(id);
      }
    }
    _sankalpMantraIds = ids;
    notifyListeners();
  }

  Future<void> createSankalp({
    required int mantraId,
    required int totalGoal,
    required DateTime startDate,
    required DateTime endDate,
    SankalpMode mode = SankalpMode.daily,
  }) async {
    final sankalp = Sankalp(
      mantraId: mantraId,
      totalGoal: totalGoal,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
      mode: mode,
    );
    await AppDatabase.insertSankalp(sankalp);
    _sankalpMantraIds.add(mantraId);
    await loadForMantra(mantraId);
  }

  Future<void> cancelSankalp() async {
    if (_activeSankalp == null) return;
    await AppDatabase.cancelSankalp(_activeSankalp!.id!);
    final mantraid = _activeSankalp!.mantraId;
    _activeSankalp = null;
    _engine = null;
    _sankalpMantraIds.remove(mantraid);
    await loadHistory();
    notifyListeners();
  }

  Future<void> refresh(int mantraId) async {
    await loadForMantra(mantraId);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  SankalpEngine? get engine => _engine;
  Sankalp? get activeSankalp => _activeSankalp;
  bool get isLoading => _isLoading;
  bool get hasActiveSankalp => _activeSankalp != null && !(_engine?.isComplete ?? false);

  Future<void> loadForMantra(int mantraId) async {
    _isLoading = true;
    notifyListeners();

    _activeSankalp = await AppDatabase.getActiveSankalp(mantraId);
    if (_activeSankalp != null) {
      final count = await AppDatabase.getCountSinceDate(
        mantraId,
        _activeSankalp!.startDate,
      );
      _engine = SankalpEngine(sankalp: _activeSankalp!, completedCount: count);

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

  Future<void> createSankalp({
    required int mantraId,
    required int totalGoal,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sankalp = Sankalp(
      mantraId: mantraId,
      totalGoal: totalGoal,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );
    await AppDatabase.insertSankalp(sankalp);
    await loadForMantra(mantraId);
  }

  Future<void> refresh(int mantraId) async {
    await loadForMantra(mantraId);
  }
}

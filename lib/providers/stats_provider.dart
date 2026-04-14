import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

final statsProvider = ChangeNotifierProvider<StatsNotifier>((ref) {
  return StatsNotifier();
});

class StatsNotifier extends ChangeNotifier {
  int _currentStreak = 0;
  List<DailyCount> _weeklyData = [];
  bool _isLoading = false;

  int get currentStreak => _currentStreak;
  List<DailyCount> get weeklyData => _weeklyData;
  bool get isLoading => _isLoading;

  Future<void> loadForMantra(int mantraId) async {
    _isLoading = true;
    notifyListeners();

    _currentStreak = await AppDatabase.getCurrentStreak(mantraId);
    _weeklyData = await AppDatabase.getDailyCounts(mantraId, 7);

    _isLoading = false;
    notifyListeners();
  }
}

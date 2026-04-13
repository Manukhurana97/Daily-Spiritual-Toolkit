import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/panchang_data.dart';

final panchangProvider = ChangeNotifierProvider<PanchangNotifier>((ref) {
  return PanchangNotifier();
});

class PanchangNotifier extends ChangeNotifier {
  PanchangData? _today;
  bool _isLoading = true;
  String? _error;

  PanchangData? get today => _today;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final jsonStr = await rootBundle.loadString('assets/panchang/panchang_2026.json');
      final Map<String, dynamic> data = json.decode(jsonStr);

      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (data.containsKey(todayKey)) {
        final dayData = Map<String, dynamic>.from(data[todayKey]);
        dayData['date'] = todayKey;
        _today = PanchangData.fromMap(dayData);
      } else {
        _today = PanchangData.placeholder(todayKey);
      }

      _error = null;
    } catch (e) {
      _error = 'Could not load panchang data.';
      _today = PanchangData.placeholder(
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      debugPrint('Panchang load error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}

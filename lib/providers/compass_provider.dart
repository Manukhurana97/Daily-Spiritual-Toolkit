import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final compassProvider = ChangeNotifierProvider<CompassNotifier>((ref) {
  return CompassNotifier();
});

class CompassNotifier extends ChangeNotifier {
  double? _heading;
  bool _hasPermission = false;
  bool _isAvailable = false;
  bool _needsCalibration = false;
  StreamSubscription<CompassEvent>? _subscription;

  double? get heading => _heading;
  bool get hasPermission => _hasPermission;
  bool get isAvailable => _isAvailable;
  bool get needsCalibration => _needsCalibration;

  String get cardinalDirection {
    if (_heading == null) return '—';
    final h = _heading!;
    if (h >= 337.5 || h < 22.5) return 'N';
    if (h >= 22.5 && h < 67.5) return 'NE';
    if (h >= 67.5 && h < 112.5) return 'E';
    if (h >= 112.5 && h < 157.5) return 'SE';
    if (h >= 157.5 && h < 202.5) return 'S';
    if (h >= 202.5 && h < 247.5) return 'SW';
    if (h >= 247.5 && h < 292.5) return 'W';
    return 'NW';
  }

  String get cardinalDirectionFull {
    switch (cardinalDirection) {
      case 'N': return 'North';
      case 'NE': return 'North-East';
      case 'E': return 'East';
      case 'SE': return 'South-East';
      case 'S': return 'South';
      case 'SW': return 'South-West';
      case 'W': return 'West';
      case 'NW': return 'North-West';
      default: return '—';
    }
  }

  /// Degrees the user must rotate clockwise to face East.
  double get degreesToEast {
    if (_heading == null) return 0;
    return (90 - _heading! + 360) % 360;
  }

  bool get isFacingEast {
    if (_heading == null) return false;
    final diff = (90 - _heading!).abs();
    return diff <= 15 || diff >= 345;
  }

  Future<void> initialize() async {
    _isAvailable = (await FlutterCompass.events?.first) != null;
    _hasPermission = true;
    _startListening();
    notifyListeners();
  }

  void _startListening() {
    _subscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _heading = event.heading;
        final accuracy = event.accuracy;
        final wasNeeding = _needsCalibration;
        _needsCalibration = accuracy != null && accuracy < 0;
        if (_needsCalibration != wasNeeding || !_needsCalibration) {
          notifyListeners();
        } else {
          notifyListeners();
        }
      }
    });
  }

  void dismissCalibration() {
    _needsCalibration = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

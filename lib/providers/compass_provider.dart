import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/legacy.dart';

final compassProvider = ChangeNotifierProvider<CompassNotifier>((ref) {
  return CompassNotifier();
});

class PilgrimageSite {
  final String name;
  final double lat;
  final double lng;
  const PilgrimageSite(this.name, this.lat, this.lng);
}

class CompassNotifier extends ChangeNotifier {
  double? _heading;
  bool _hasPermission = false;
  bool _isAvailable = false;
  bool _needsCalibration = false;
  bool _spiritualMode = false;
  double? _userLat;
  double? _userLng;
  StreamSubscription<CompassEvent>? _subscription;

  static const pilgrimages = [
    PilgrimageSite('Vrindavan', 27.4936, 77.6737),
    PilgrimageSite('Kashi', 25.3176, 83.0063),
    PilgrimageSite('Kedarnath', 30.7346, 79.0669),
  ];

  double? get heading => _heading;
  bool get hasPermission => _hasPermission;
  bool get isAvailable => _isAvailable;
  bool get needsCalibration => _needsCalibration;
  bool get spiritualMode => _spiritualMode;

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
    return switch (cardinalDirection) {
      'N' => 'North',
      'NE' => 'North-East',
      'E' => 'East',
      'SE' => 'South-East',
      'S' => 'South',
      'SW' => 'South-West',
      'W' => 'West',
      'NW' => 'North-West',
      _ => '—',
    };
  }

  double get degreesToEast {
    if (_heading == null) return 0;
    return (90 - _heading! + 360) % 360;
  }

  bool get isFacingEast {
    if (_heading == null) return false;
    final diff = (90 - _heading!).abs();
    return diff <= 15 || diff >= 345;
  }

  bool get isFacingNorthEast {
    if (_heading == null) return false;
    final diff = (45 - _heading!).abs();
    return diff <= 15 || diff >= 345;
  }

  /// Convert direction name to degrees ()=N, 90=E, etc.)
  static double? directionToDegress(String? direction) {
    if (direction == null) return null;
    final d = direction.trim().toLowerCase();
    return switch (d) {
      'north' || 'n' => 0,
      'north-east' || 'northeast' || 'ne' => 45,
      'east' || 'e'=> 90,
      'south-east' || 'southeast' || 'se' => 135,
      'south' || 's' => 180,
      'south-west' || 'southwest' || 'sw' => 225,
      'west' || 'w' => 270,
      'north-west' || 'northwest' || 'nw' => 315,
      _ => null,
    };
  }

  /// Returns guidance string if user is NOT facing the target direction(±15°)
  /// Returns null if facing correctly or compass unavailable
  String? directionGuidance(String? targetDirection) {
    if (_heading == null || targetDirection == null) return null;
    final targetDeg = directionToDegress(targetDirection);
    if(targetDeg == null) return null;
    // Shorted angular difference
    double diff = targetDeg - _heading!;
    if (diff > 180) diff -= 360;
    if (diff <- 180) diff += 360;
    if (diff.abs() <= 15) return null; //correctly facing
    return diff > 0 ? "Turn right ⤴" : "Turn Left ⤵";
  }

  /// Whether user is facing targetDirection with ±15°
  bool isFacingDirection(String? targetDirection) {
    return directionGuidance(targetDirection) == null && _heading != null && targetDirection != null;
  }

  void setUserLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    notifyListeners();
  }

  void toggleSpiritualMode() {
    _spiritualMode = !_spiritualMode;
    notifyListeners();
  }

  /// Bearing from user's location to a pilgrimage site (in degrees 0-360).
  double? bearingTo(PilgrimageSite site) {
    if (_userLat == null || _userLng == null) return null;
    return _calcBearing(_userLat!, _userLng!, site.lat, site.lng);
  }

  static double _calcBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRad(lng2 - lng1);
    final lat1R = _toRad(lat1);
    final lat2R = _toRad(lat2);

    final y = sin(dLng) * cos(lat2R);
    final x = cos(lat1R) * sin(lat2R) - sin(lat1R) * cos(lat2R) * cos(dLng);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  static double _toRad(double deg) => deg * pi / 180;

  Future<void> initialize() async {
    try {
      final firstEvent = await FlutterCompass.events?.first.timeout(
        const Duration(seconds: 3),
      );
      _isAvailable = firstEvent != null;
    } catch (_) {
      _isAvailable = false;
    }

    _hasPermission = true;
    _startListening();
    notifyListeners();
  }

  double? _accuracy;
  bool _calibrationDismissed = false;

  double? get accuracy => _accuracy;
  bool get isLowAccuracy => _accuracy != null && _accuracy! >= 0 && _accuracy! < 25;

  void _startListening() {
    _subscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _heading = event.heading;
        _accuracy = event.accuracy;
        final unreachable = _accuracy != null && _accuracy! < 0;
        if (unreachable && !_calibrationDismissed) {
          _needsCalibration = true;
        } else if (!unreachable && _needsCalibration) {
          _needsCalibration = false;
        }
        notifyListeners();
      }
    });
  }

  void dismissCalibration() {
    _needsCalibration = false;
    _calibrationDismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

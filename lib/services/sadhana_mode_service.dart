import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final sadhanaModeProvider = ChangeNotifierProvider<SadhanaModeNotification>((ref) {
  return SadhanaModeNotification();
});

class SadhanaModeNotification extends ChangeNotifier {
  static const _dndChannel = MethodChannel('com.manukhurana.naam_jap/dnd');

  bool _isActive = false;
  Duration? _timerDuration;
  DateTime? _startedAt;
  Timer? _autoOffTimer;
  bool _hasAndroidDndPermission = false;
  bool _iosGuideShown = false;

  bool get isActive => _isActive;
  Duration? get timerDuration => _timerDuration;
  DateTime? get startedAt => _startedAt;
  Duration? get elapsed => _startedAt != null ? DateTime.now().difference(_startedAt!) : null;
  Duration? get remaining {
    if (_timerDuration == null || _startedAt == null) return null;
    final left = _timerDuration! - DateTime.now().difference(_startedAt!);
    return left.isNegative ? Duration.zero : left;
  }
  bool get hasAndroidDndPermission => _hasAndroidDndPermission;
  bool get iosGuideShown => _iosGuideShown;

  Future<void> initialize() async {
    if (Platform.isAndroid) {
      try {
        _hasAndroidDndPermission = await _dndChannel.invokeMethod<bool>('requestPermission') ?? false;
      } catch (e) {
        debugPrint('DND permission check error: $e');
      }
    }
    notifyListeners();
  }

  /// Request Android DND permission (opens system settings)
  Future<bool> requestAndroidPermission() async {
    if(!Platform.isAndroid) return false;
    try {
      _hasAndroidDndPermission = await _dndChannel.invokeMethod<bool>('requestPermission') ?? false;
      notifyListeners();
      return _hasAndroidDndPermission;
    } catch (e) {
      debugPrint('DND request permission error: $e');
      return false;
    }
  }

  /// Activate Sadhana Mode.
  /// [duration] - optional auto-off timer. If null, stays on until manually turned off.
  Future<void> activate({Duration? duration}) async {
    _isActive = true;
    _startedAt = DateTime.now();
    _timerDuration = duration;

    // Enable Android system DND
    if (Platform.isAndroid && _hasAndroidDndPermission) {
      try {
        await _dndChannel.invokeMethod('enableDnd');
      } catch (e) {
        debugPrint('DND enable error: $e');
      }
    }

    // Set auto-off timer
    _autoOffTimer?.cancel();
    if (duration != null) {
      _autoOffTimer = Timer(duration, () {
        deactivate();
      });
    }

    notifyListeners();
  }

  /// Deactivate Sadhana Mode.
  Future<void> deactivate() async {
    _isActive = false;
    _autoOffTimer?.cancel();
    _autoOffTimer = null;
    _timerDuration = null;
    _startedAt = null;

    // Disable Android system DND (restore previous filter)
    if (Platform.isAndroid && _hasAndroidDndPermission) {
      try {
        await _dndChannel.invokeMethod('disableDnd');
      } catch (e) {
        debugPrint('DND disable error: $e');
        debugPrint('DND disable error: $e');
      }
    }

    notifyListeners();
  }

  void markIosGuideShown() {
    _iosGuideShown = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoOffTimer?.cancel();
    // Ensure DND is restored if app is killed while active
    if (_isActive && Platform.isAndroid) {
      _dndChannel.invokeMethod('disableDnd').catchError((_) {});
    }
    super.dispose();
  }

}

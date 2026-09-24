import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';

final deviceServiceProvider = ChangeNotifierProvider<DeviceService>((ref) {
  return DeviceService();
});

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime? lastActiveAt;
  final DateTime? registeredAt;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.lastActiveAt,
    this.registeredAt,
  });

  Map<String, dynamic> toMap() => {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'lastActiveAt': lastActiveAt != null
        ? Timestamp.fromDate(lastActiveAt!)
          : FieldValue.serverTimestamp(),
      'registeredAt': registeredAt != null
        ? Timestamp.fromDate(registeredAt!)
          : FieldValue.serverTimestamp(),

    };

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
        deviceId: map['deviceId'] as String? ?? '',
        deviceName: map['deviceName'] as String? ?? 'Unknown',
        platform: map['platform'] as String? ?? 'Unknown',
        lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
        registeredAt: (map['registeredAt'] as Timestamp?)?.toDate(),
    );
  }
}

enum DeviceAuthStatus {
  authorized,
  limitReached,
  notSignedIn,
  notPremium,
  error,
}

class DeviceService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _deviceId;
  String? _deviceName;
  bool _isAuthorized = false;
  bool _deviceLimitReached = false;
  List<DeviceInfo> _activeDevices = [];
  int _maxDevices = 1;

  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  bool get isAuthorized => _isAuthorized;
  bool get deviceLimitReached => _deviceLimitReached;
  List<DeviceInfo> get activeDevices => List.unmodifiable(_activeDevices);
  int get maxDevices => _maxDevices;

  /// Generate a stable device ID using platform-specific identifiers.
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        _deviceId = android.id;
        _deviceName = '${android.brand} ${android.model}';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        _deviceId = ios.identifierForVendor ?? await _generateFallbackId();
        _deviceName = ios.utsname.machine;
      } else {
        _deviceId = await _generateFallbackId();
        _deviceName = 'Unknown Device';
      }
    } catch (e) {
      AppLogger.error('[DeviceService] Failed to get device info', error: e);
      _deviceId = await _generateFallbackId();
      _deviceName = 'Unknown Device';
    }

    return _deviceId!;
  }

  Future<String> _generateFallbackId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_uuid');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_uuid', id);
    }

    return id;
  }

  /// Check if this device is authorized for this user.
  /// Return the status. If [limitReached], caller should show the limit screen.
  Future<DeviceAuthStatus> checkDeviceAuthorization() async {
    final user = _auth.currentUser;
    if (user == null) return DeviceAuthStatus.notSignedIn;

    try {
      final deviceId = await getDeviceId();
      final uid = user.uid;

      final userDoc = await _firestore.doc('user/$uid').get();

      if(!userDoc.exists) {
        // First time - create user documents and register this device
        await _createUserDocument(uid, deviceId);
        _isAuthorized = true;
        notifyListeners();
        return DeviceAuthStatus.authorized;
      }

      final data = userDoc.data()!;
      _maxDevices = (data['maxDevices'] as int?) ?? 1;
      final rawDevices = data['activeDevices'] as List<dynamic>? ?? [];
      _activeDevices = rawDevices
        .map((d) => DeviceInfo.fromMap(Map<String, dynamic>.from(d as Map)))
      .toList();

      // Check if this device is already registered
      final isRegistered = _activeDevices.any((d) => d.deviceId == deviceId);

      if (isRegistered) {
        await _updateLastActive(uid, deviceId);
        _isAuthorized = true;
        notifyListeners();
        return DeviceAuthStatus.authorized;
      }

      // New Device - check limit
      if(_activeDevices.length >= _maxDevices) {
        _isAuthorized = false;
        _deviceLimitReached = true;
        notifyListeners();
        return DeviceAuthStatus.limitReached;
      }

      // Under limit - registered automatically
      await registerDevice(uid, deviceId);
      _isAuthorized = true;
      _deviceLimitReached = false;
      notifyListeners();
      return DeviceAuthStatus.authorized;
    } catch (e, st) {
      AppLogger.error('[DeviceService] checkDeviceAuthorization error', error: e, stackTrace: st);
      // On error, allow usage (graceful degradation)
      _isAuthorized = true;
      notifyListeners();
      return DeviceAuthStatus.error;
    }
  }

  Future<void> _createUserDocument(String uid, String deviceId) async {
    final device = DeviceInfo(
        deviceId: deviceId,
        deviceName: deviceName ?? 'Unknown',
        platform: Platform.isAndroid ? 'android' : 'ios',
    );

    await _firestore.doc('users/$uid').set({
      'maxDevices': 1,
      'subscriptionTier': 'premium',
      'activeDevices': [device.toMap()],
      'createdAt': FieldValue.serverTimestamp(),
    });

    _activeDevices = [device];
    _maxDevices = 1;

    AppLogger.info('[DeviceService] Created user document and registered device');
  }

  Future<void> registerDevice(String uid, String deviceId) async {
    final device = DeviceInfo(
        deviceId: deviceId,
        deviceName: _deviceName ?? 'Unknown',
        platform: Platform.isAndroid ? 'android' : 'ios',
    );

    await _firestore.doc('users/$uid').update({
      'activeDevices': FieldValue.arrayUnion([device.toMap()])
    });

    _activeDevices.add(device);
    _isAuthorized = true;
    notifyListeners();

    AppLogger.info('[DeviceService] Registered device: $deviceId');
  }

  /// Remove a device from the active list (user-choice kick)
  Future<void> removeDevice(String deviceIdToRemove) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    try{
      final userDoc = await _firestore.doc('users/$uid').get();
      if (!userDoc.exists) return;

      final rawDevices =
          userDoc.data()!['activeDevices'] as List<dynamic>? ?? [];
      final devices =
        rawDevices.map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
      devices.removeWhere((d) => d['deviceId'] == deviceIdToRemove);

      await _firestore.doc('users/$uid').update({'activeDevices': devices});

      _activeDevices.removeWhere((d) => d.deviceId == deviceIdToRemove);
      notifyListeners();

      AppLogger.info('[DeviceService] Removed device, $deviceIdToRemove');
    } catch (e, st) {
      AppLogger.error('[DeviceService] removeDevice error', error: e, stackTrace: st);
    }
  }

  /// Remove old device and register this device (kick + replace flow)
  Future<void> replaceDevice(String oldDeviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final newDeviceId = await getDeviceId();

    await removeDevice(oldDeviceId);
    await registerDevice(uid, newDeviceId);
    _deviceLimitReached = false;
    notifyListeners();
  }

  /// Unregister this device (user on sign out)
  Future<void> unregisterThisDevice() async {
    if (_deviceId == null) return;
    await removeDevice(_deviceId!);
    _isAuthorized = false;
    notifyListeners();
  }

  Future<void> _updateLastActive(String uid, String deviceId) async {
    try {
      final userDoc = await _firestore.doc('users/$uid').get();
      if (!userDoc.exists) return;

      final rawDevice =
          userDoc.data()!['activeDevices'] as List<dynamic>? ?? [];
      final devices = rawDevice
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

      for (final device in devices) {
        if (device['devicesId'] == deviceId) {
          device['lastActiveAt'] = Timestamp.now();
          break;
        }
      }

      await _firestore.doc('users/$uid').update({'activeDevices' : devices});
    } catch (e) {
      debugPrint('[DeviceService] _updateLastActive error: $e');
    }
  }

  /// Reload device data from Firestore (pull latest)
  Future<void> refreshDevices() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.doc('users/${user.uid}').get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      _maxDevices = (data['maxDevices'] as int?) ?? 1;
      final rawDevices = data['activeDevices']  as List<dynamic>? ?? [];
      _activeDevices = rawDevices
        .map((d) => DeviceInfo.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

      final deviceId = await getDeviceId();
      _isAuthorized = _activeDevices.any((d) => d.deviceId == deviceId);

      notifyListeners();
    } catch (e, st) {
      AppLogger.error('[DeviceService] refreshDevices error', error: e, stackTrace: st);
    }
  }
}
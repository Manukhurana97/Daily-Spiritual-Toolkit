import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nitya_sadhana/database/app_database.dart';
import 'package:nitya_sadhana/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final backupServiceProvider = ChangeNotifierProvider<BackupService>((ref) {
  return BackupService();
});

class BackupMeta {
  final String backupId;
  final DateTime createdAt;
  final String backupType;
  final String appVersion;
  final int dataVersion;
  final int sizeBytes;
  final int mantraCount;
  final int sessionCount;
  final int sankalpCount;

  const BackupMeta({
    required this.backupId,
    required this.createdAt,
    required this.backupType,
    required this.appVersion,
    required this.dataVersion,
    required this.sizeBytes,
    this.mantraCount = 0,
    this.sessionCount = 0,
    this.sankalpCount = 0,
  });

  factory BackupMeta.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>?;
    return BackupMeta(
        backupId: map['backupId'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        backupType: map['backupType'] as String? ?? 'manual',
        appVersion: map['appVersion'] as String? ?? '?',
        dataVersion: (map['dataVersion'] as int?) ?? 1,
        sizeBytes: (map['sizeBytes'] as int?) ?? 0,
        mantraCount: (map['mantraCount'] as List?)?.length ?? 0,
        sessionCount: (map['sessionCount'] as List?)?.length ?? 0,
        sankalpCount: (map['sankalps'] as List?)?.length ?? 0,
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _appVersion = '1.0.0';
  static const _dataVersion = 1;
  static const _maxBackup = 5;
  static const _keyBackupFrequency = 'backup_frequency';
  static const _keyLastBackupTime = 'last_backup_time';
  static const _keyLastRestoreData = 'last_restore_date';
  static const _keySafetyBackupPath = 'safety_backup_path';
  static const _undoWindowDays = 7;

  // Settings key to backup up
  static const _settingsKeyToBackup = [
    'default_mantra_id',
    'theme_mode',
    'notif_brahma_muhurta',
    'notif_sandhya_kaal',
    'mala_size',
    'daily_size',
    'notif_sound',
    'masa_system',
    'backup_frequency'
  ];

  bool _isbackingUp = false;
  bool _isRestoring = false;
  List<BackupMeta> _backupHistory = [];
  DateTime? _lastBackupTime;

  bool get isBackingUp => _isbackingUp;
  bool get isRestoring => _isRestoring;
  List<BackupMeta> get backupHistory => List.unmodifiable(_backupHistory);
  DateTime? get lastBackupTime => _lastBackupTime;

  // Whether on undo restore is available (within 7-day window).
  Future<bool> get canUndoRestore async {
    final prefs = await SharedPreferences.getInstance();
    final restoreDate = prefs.getString(_keyLastRestoreData);
    final backupPath = prefs.getString(_keySafetyBackupPath);
    if (restoreDate == null || backupPath == null) return false;

    final restoreTime = DateTime.parse(restoreDate);
    if(DateTime.now().difference(restoreTime).inDays > _undoWindowDays) {
      // Expired - clean up
      await _deleteSafetyBackup(backupPath);
      await prefs.remove(_keyLastRestoreData);
      await prefs.remove(_keySafetyBackupPath);
      return false;
    }

    return File(backupPath).existsSync();
  }

  /// Get the user's selected backup frequency
  Future<String> getBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBackupFrequency) ?? 'daily';
  }

  /// Set backup frequency preference.
  Future<void> setBackupFrequency(String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackupFrequency, frequency);
    notifyListeners();
  }

  // - CREATE BACKUP -
  /// Create a cloud backup of all user data.
  Future<bool> createBackup({bool isManual = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    _isbackingUp = true;
    notifyListeners();

    try {
      final uid = user.uid;

      // 1. Export all SQLite data
      final mantras = await AppDatabase.exportMantras();
      final sessions = await AppDatabase.exportSessions();
      final sankalps = await AppDatabase.exportSankalps();
      final settings = await _exportSettings();

      final backupData = {
        'mantra': mantras,
        'japaSessions': sessions,
        'sankalps': sankalps,
        'settings': settings,
      };

      // 2. Calculate size
      final jsonStr = jsonEncode(backupData);
      final sizeBytes = utf8.encode(jsonStr).length;

      // 3. Upload to FireBase
      final backupId = 'backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}';
      await _firestore
          .collection('backup')
          .doc(uid)
          .collection('snapshots')
          .doc(backupId)
          .set({
        'userId': uid,
        'backupId': backupId,
        'createdAt': FieldValue.serverTimestamp(),
        'backupType': isManual ? 'manual': 'auto',
        '_appVersion': _appVersion,
        '_dataVersion': _dataVersion,
        'sizeBytes': sizeBytes,
        'data': backupData
      });

      // 4. Save last backup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastBackupTime, DateTime.now().toIso8601String());
      _lastBackupTime = DateTime.now();

      // 5. Cleanup old backups
      await _cleanupOldBackups(uid);

      // 6. Refresh history
      await loadbackupHistory();

      AppLogger.info(
        '[BackupService] Backup created: $backupId (${(sizeBytes / 1024).toStringAsFixed(1)} KB)'
      );

      _isbackingUp = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('[BackupService] createBackup error', error: e, stackTrace: st);
      _isbackingUp = false;
      notifyListeners();
      return false;
    }
  }

  // Auto-Backup Scheduler

  /// Check if auto-backup should run based on user's frequency settings
  Future<void> scheduledAutoBackup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final frequency = await getBackupFrequency();
      if (frequency == 'manual') return;

      final prefs = await SharedPreferences.getInstance();
      final lastBackupStr = prefs.getString(_keyLastBackupTime);

      if (lastBackupStr == null) {
        // Never backup up - do it now
        await createBackup(isManual: false);
        return;
      }

      final lastBackup = DateTime.parse(lastBackupStr);
      _lastBackupTime = lastBackup;

      final shouldBackup = switch (frequency) {
        'daily' =>
            lastBackup.isBefore(
                DateTime.now().subtract(const Duration(days: 1))),
        'weekly' =>
            lastBackup.isBefore(
                DateTime.now().subtract(const Duration(days: 7))),
        'monthly' =>
            lastBackup.isBefore(
                DateTime.now().subtract(const Duration(days: 30))),
        _ => false,
      };

      if (shouldBackup) {
        AppLogger.info(
            '[BackupService] Auto-backup triggered (frequency: $frequency)');
        await createBackup(isManual: false);
      }
    } catch (e, st) {
      AppLogger.error(
         '[BackupService] scheduleAutoBackup error', error: e, stackTrace: st);
    }
  }

  // BACKUP HISTORY

  /// Load backup history from Firestore.
  Future<void> loadbackupHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshots = await _firestore
          .collection('backup')
          .doc(user.uid)
          .collection('snapshots')
          .orderBy('createdAt', descending: true)
          .limit(_maxBackup)
          .get();

      _backupHistory =
          snapshots.docs.map((doc) => BackupMeta.fromMap(doc.data())).toList();

      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString(_keyLastBackupTime);
      _lastBackupTime = lastStr != null ? DateTime.tryParse(lastStr) : null;

      notifyListeners();
    } catch (e, st) {
      AppLogger.error('[BackupService] loadBackupHistory error', error: e, stackTrace: st);
    }
  }

  // Restore
  /// Restore all data from a cloud backup. Full replace with safety net.
  Future<bool> restoreBackup(String backupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if(user == null) return false;

    _isRestoring = true;
    notifyListeners();

    try {
      final uid = user.uid;

      // 1. create local safety net backup
      await _createLocalSafetyBackup();

      // 2. Fetch backup from Firestore.
      final snapshot = await _firestore
        .collection('backup')
        .doc(uid)
        .collection('snapshots')
        .doc(backupId)
        .get();

      if (!snapshot.exists) {
        _isRestoring = false;
        notifyListeners();
        return false;
      }

      final data = snapshot.data()!['data'] as Map<String, dynamic>;

      // 3. Clear all current data
      final mantras = (data['mantras'] ?? data['mantra']) as List<dynamic>? ?? [];
      for (final mantra in mantras) {
        await AppDatabase.importMantraRaw(
          Map<String, dynamic>.from(mantra as Map));
      }

      final sessions = data['japaSessions'] as List<dynamic>? ?? [];
      for (final session in sessions) {
        await AppDatabase.importSessionRaw(
          Map<String, dynamic>.from(session as Map));
      }

      final sankalps = data['sankalps'] as List<dynamic>? ?? [];
      for (final sankalp in sankalps) {
        await AppDatabase.importSankalpRaw(
          Map<String, dynamic>.from(sankalp as Map));
      }

      // 5. Restore settings
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        await _importSettings(settings);
      }

      // 6. Save undo metadata
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastRestoreData, DateTime.now().toIso8601String());

      AppLogger.info('[BackupService] Restore completed from: $backupId');

      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('[BackupService] restoreBackup error',
        error: e, stackTrace: st);

      _isRestoring = false;
      notifyListeners();
      return false;
    }
  }

  // UNDO RESTORE

  // Undo the last restore using the local safety backup.
  Future<bool> undoRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final restoreDate = prefs.getString(_keyLastRestoreData);
    final backupPath = prefs.getString(_keySafetyBackupPath);

    if (restoreDate == null || backupPath == null) return false;

    final restoreTime = DateTime.parse(restoreDate);
    if (DateTime.now().difference(restoreTime).inDays > _undoWindowDays) {
      await _deleteSafetyBackup(backupPath);
      await prefs.remove(_keyLastRestoreData);
      await prefs.remove(_keySafetyBackupPath);
      return false;
    }

    _isRestoring = true;
    notifyListeners();

    try {
      final file = File(backupPath);
      if (!file.existsSync()) {
        _isRestoring = false;
        notifyListeners();
        return false;
      }

      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Clear and import
      await AppDatabase.clearAllTables();

      final mantras = data['mantras'] as List<dynamic>? ?? [];
      for (final mantra in mantras) {
        await AppDatabase.importMantraRaw(
          Map<String, dynamic>.from(mantra as Map));
      }

      final sessions = data['japaSessions'] as List<dynamic>? ?? [];
      for (final session in sessions) {
        await AppDatabase.importMantraRaw(
          Map<String, dynamic>.from(session as Map));
      }

      final sankalps = data['sankalps'] as List<dynamic>? ?? [];
        for (final sankalp in sankalps) {
          await AppDatabase.importSankalpRaw(
            Map<String, dynamic>.from(sankalp as Map));
      }

      final settings = data['settings'] as Map<String, dynamic>?;
      if(settings != null) {
        await _importSettings(settings);
      }

      // Cleanup
      await _deleteSafetyBackup(backupPath);
      await prefs.remove(_keyLastRestoreData);
      await prefs.remove(_keySafetyBackupPath);

      AppLogger.info('[BackupService] Undo restore completed');

      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('[BackupService undoRestore error]', error: e, stackTrace: st);
      _isRestoring = false;
      notifyListeners();
      return false;
    }
  }

  // Safety net
  Future<void> _createLocalSafetyBackup() async {
    try {
      final mantras = await AppDatabase.exportMantras();
      final sessions = await AppDatabase.exportSessions();
      final sankalps = await AppDatabase.exportSankalps();
      final settings = await _exportSettings();

      final backupData = {
        'mantras': mantras,
        'japaSessions': sessions,
        'sankalps': sankalps,
        'settings': settings
      };

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/safety_backup.json';
      final file = File(path);
      await file.writeAsString(jsonEncode(backupData));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySafetyBackupPath, path);

      AppLogger.info('[BackupService] Local safety backup created: $path');
    } catch (e, st) {
      AppLogger.error('[BackupService] _createLocalSafetyBackup error',
      error: e, stackTrace: st);
    }
  }

  Future<void> _deleteSafetyBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[BackupService] Failed to delete safety backup: $e');
    }
  }

  /// Auto delete expired safety backups (Call on app start).
  Future<void> cleanupExpiredSafetyBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final restoreDate = prefs.getString(_keyLastRestoreData);
    final backupPath = prefs.getString(_keySafetyBackupPath);

    if (restoreDate == null || backupPath == null) return;

    final restoreTime = DateTime.parse(restoreDate);
    if (DateTime.now().difference(restoreTime).inDays > _undoWindowDays) {
      await _deleteSafetyBackup(backupPath);
      await prefs.remove(_keyLastRestoreData);
      await prefs.remove(_keySafetyBackupPath);
      AppLogger.info('[BackupService] Expired safety backup cleaned up');
    }
  }

  // Settings Export/Import
  Future<Map<String, dynamic>> _exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};

    for(final key in _settingsKeyToBackup) {
      final value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    return settings;
  }


  Future<void> _importSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in settings.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    }
  }


  // Cleanup

  Future<void> _cleanupOldBackups(String uid) async {
    try {
      final snapshots = await _firestore
        .collection('backup')
        .doc(uid)
        .collection('snapshots')
        .orderBy('createdAt', descending: true)
        .get();

      if (snapshots.docs.length > _maxBackup) {
        final toDelete = snapshots.docs.sublist(_maxBackup);
        for (final doc in toDelete) {
          await doc.reference.delete();
        }
        AppLogger.info(
          '[BackupService] Cleaned up ${toDelete.length} old backups');
      }
    } catch (e) {
      debugPrint('[BackupService] _cleanupOldBackups error: $e');
    }
  }
}
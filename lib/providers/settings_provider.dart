import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = ChangeNotifierProvider<SettingsNotifier>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends ChangeNotifier {
  static const _keyDefaultMantraId = 'default_mantra_id';
  static const _keyLocale = 'locale';
  static const _keyThemeMode = 'theme_mode';
  static const _keyBrahmaMuhurtaNotif = 'notif_brahma_muhurta';
  static const _keySandhyaKaalNotif = 'notif_sandhya_kaal';
  static const _keyMalaSize = 'mala_size';
  static const _keyDailySize = 'daily_size';
  static const _keyNotifSound = 'notif_sound';

  SharedPreferences? _prefs;
  int? _defaultMantraId;
  String _locale = 'system';
  ThemeMode _themeMode = ThemeMode.system;
  bool _brahmaMuhurtaNotif = false;
  bool _sandhyaKaalNotif = false;
  int _malaSize = 108;
  int _dailyGoal = 0;
  String _notifSound = 'default';
  bool _isLoading = true;

  int? get defaultMantraId => _defaultMantraId;
  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get brahmaMuhurtaNotif => _brahmaMuhurtaNotif;
  bool get sandhyaKaalNotif => _sandhyaKaalNotif;
  int get malaSize => _malaSize;
  int get dailyGoal => _dailyGoal;
  String get notifSound => _notifSound;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _prefs = await SharedPreferences.getInstance();
    _defaultMantraId = _prefs?.getInt(_keyDefaultMantraId);
    _locale = _prefs?.getString(_keyLocale) ?? 'system';

    final themeName = _prefs?.getString(_keyThemeMode) ?? 'system';
    _themeMode = switch (themeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _brahmaMuhurtaNotif = _prefs?.getBool(_keyBrahmaMuhurtaNotif) ?? false;
    _sandhyaKaalNotif = _prefs?.getBool(_keySandhyaKaalNotif) ?? false;
    _malaSize = _prefs?.getInt(_keyMalaSize) ?? 108;
    _dailyGoal = _prefs?.getInt(_keyDailySize) ?? 0;
    _notifSound = _prefs?.getString(_keyNotifSound) ?? 'default';
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setDefaultMantraId(int? id) async {
    _defaultMantraId = id;
    if (id != null) {
      await _prefs?.setInt(_keyDefaultMantraId, id);
    } else {
      await _prefs?.remove(_keyDefaultMantraId);
    }
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _locale = locale;
    await _prefs?.setString(_keyLocale, locale);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final name = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs?.setString(_keyThemeMode, name);
    notifyListeners();
  }

  Future<void> setBrahmaMuhurtaNotif(bool enabled) async {
    _brahmaMuhurtaNotif = enabled;
    await _prefs?.setBool(_keyBrahmaMuhurtaNotif, enabled);
    notifyListeners();
  }

  Future<void> setSandhyaKaalNotif(bool enabled) async {
    _sandhyaKaalNotif = enabled;
    await _prefs?.setBool(_keySandhyaKaalNotif, enabled);
    notifyListeners();
  }

  Future<void> setMalaSize(int size) async {
    _malaSize = size;
    await _prefs?.setInt(_keyMalaSize, size);
    notifyListeners();
  }

  Future<void> setDailyGoal(int goal) async {
    _dailyGoal = goal;
    await _prefs?.setInt(_keyDailySize, goal);
    notifyListeners();
  }

  Future<void> setNotifSound(String sound) async {
    _notifSound = sound;
    await _prefs?.setString(_keyNotifSound, sound);
    notifyListeners();
  }
}

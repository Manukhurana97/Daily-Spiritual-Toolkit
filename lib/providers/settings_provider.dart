import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = ChangeNotifierProvider<SettingsNotifier>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends ChangeNotifier {
  static const _keyDefaultMantraId = 'default_mantra_id';
  static const _keyLocale = 'locale';

  SharedPreferences? _prefs;
  int? _defaultMantraId;
  String _locale = 'system';
  bool _isLoading = true;

  int? get defaultMantraId => _defaultMantraId;
  String get locale => _locale;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _prefs = await SharedPreferences.getInstance();
    _defaultMantraId = _prefs?.getInt(_keyDefaultMantraId);
    _locale = _prefs?.getString(_keyLocale) ?? 'system';

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
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/panchang_data.dart';
import '../services/panchang_calculator.dart';

final panchangProvider = ChangeNotifierProvider<PanchangNotifier>((ref) {
  return PanchangNotifier();
});

class PanchangNotifier extends ChangeNotifier {
  static const _defaultLat = 28.6139;
  static const _defaultLng = 77.2090;
  static const _defaultCity = 'New Delhi';

  List<PanchangData> _days = [];
  bool _isLoading = true;
  String? _error;
  bool _usingDefaultLocation = false;

  List<PanchangData> get days => _days;
  PanchangData? get today => _days.isNotEmpty ? _days[0] : null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get usingDefaultLocation => _usingDefaultLocation;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await PanchangCalculator.init();

      final position = await _getLocation();
      final double lat;
      final double lng;
      final String? locationLabel;

      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        locationLabel = null;
        _usingDefaultLocation = false;
      } else {
        lat = _defaultLat;
        lng = _defaultLng;
        locationLabel = _defaultCity;
        _usingDefaultLocation = true;
      }

      final now = DateTime.now();
      final timeFormat = DateFormat('hh:mm a');

      _days = List.generate(7, (i) {
        final date = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        final result = PanchangCalculator.calculate(date, lat, lng);
        return _resultToData(result, date, timeFormat, locationLabel);
      });
      _error = null;
    } catch (e) {
      debugPrint('Panchang calculation error: $e');
      _error = 'Could not calculate panchang data.';
      final now = DateTime.now();
      _days = List.generate(7, (i) {
        final date = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        return PanchangData.placeholder(DateFormat('yyyy-MM-dd').format(date));
      });
    }

    _isLoading = false;
    notifyListeners();
  }

  PanchangData _resultToData(
    PanchangResult result,
    DateTime date,
    DateFormat timeFormat,
    String? locationLabel,
  ) {
    return PanchangData(
      date: DateFormat('yyyy-MM-dd').format(date),
      tithi: result.tithi.name,
      tithiEndTime: timeFormat.format(result.tithiTransition.endTime),
      nextTithi: result.tithiTransition.nextName,
      nakshatra: result.nakshatra.name,
      nakshatraPada: 'Pada ${result.nakshatra.pada}',
      nakshatraEndTime: timeFormat.format(result.nakshatraTransition.endTime),
      nextNakshatra: result.nakshatraTransition.nextName,
      vaar: result.vara,
      yoga: result.yoga.name,
      yogaEndTime: timeFormat.format(result.yogaTransition.endTime),
      nextYoga: result.yogaTransition.nextName,
      karana: result.karana.name,
      karanaEndTime: timeFormat.format(result.karanaTransition.endTime),
      nextKarana: result.karanaTransition.nextName,
      sunrise: result.sunrise != null ? timeFormat.format(result.sunrise!) : '—',
      sunset: result.sunset != null ? timeFormat.format(result.sunset!) : '—',
      paksha: result.paksha,
      moonPhase: result.moonPhase,
      sunSign: result.sunSign,
      moonSign: result.moonSign,
      rahuKaalStart: result.rahuKaal != null ? timeFormat.format(result.rahuKaal!.start) : null,
      rahuKaalEnd: result.rahuKaal != null ? timeFormat.format(result.rahuKaal!.end) : null,
      auspiciousNote: _generateNote(result),
      locationLabel: locationLabel,
    );
  }

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  String _generateNote(PanchangResult result) {
    final notes = <String>[];

    if (result.tithi.name == 'Purnima') {
      notes.add('Full Moon — highly auspicious for all spiritual practices.');
    } else if (result.tithi.name == 'Amavasya') {
      notes.add('New Moon — a day for introspection and quiet jap.');
    } else if (result.tithi.name.contains('Ekadashi')) {
      notes.add('Ekadashi — fasting and Vishnu naam jap recommended.');
    } else if (result.tithi.name.contains('Chaturdashi') && result.paksha == 'Krishna Paksha') {
      notes.add('Masik Shivratri — powerful day for jap.');
    }

    final vara = result.vara.toLowerCase();
    if (vara.contains('monday')) {
      notes.add('Somvar — ideal for Shiva naam jap and meditation.');
    } else if (vara.contains('tuesday')) {
      notes.add('Mangalvar — chant Hanuman Chalisa for protection.');
    } else if (vara.contains('thursday')) {
      notes.add("Guruvar — ideal for learning and guru's blessings.");
    } else if (vara.contains('saturday')) {
      notes.add('Shanivar — chant protective mantras for Shani.');
    }

    if (notes.isEmpty) {
      notes.add('Continue your daily sadhana with devotion.');
    }

    return notes.first;
  }
}

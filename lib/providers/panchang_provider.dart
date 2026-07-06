import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart';

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
  LocationTier _locationTier = LocationTier.fallback;

  List<PanchangData> get days => _days;
  PanchangData? get today => _days.isNotEmpty ? _days[0] : null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LocationTier get locationTier => _locationTier;
  bool get usingDefaultLocation => _locationTier == LocationTier.fallback;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await PanchangCalculator.init();

      double lat;
      double lng;
      double alt;
      String? locationLabel;

      // Fallback chain: GPS -> IP geolocation -> New Delhi default
      final position = await _getGpsLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        alt = position.altitude.clamp(0, 9000);
        locationLabel = null;
        _locationTier = LocationTier.gps;
      } else {
        // Try IP-based geolocation
        final ipLoc = await _getIpLocation();
        if (ipLoc != null) {
          lat = ipLoc['lat'] as double;
          lng = ipLoc['lng'] as double;
          alt = 0; // IP geolocation doesn't provide altitude
          locationLabel = ipLoc['city'] as String?;
          _locationTier = LocationTier.ip;
        } else {
          lat = _defaultLat;
          lng = _defaultLng;
          alt = 216; // New Delhi avg elevation
          locationLabel = _defaultCity;
          _locationTier = LocationTier.fallback;
        }
      }

      final now = DateTime.now();
      final timeFormat = DateFormat('hh:mm a');

      _days = List.generate(7, (i) {
        final date = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        final result = PanchangCalculator.calculate(date, lat, lng, alt);
        if (i == 0) {
          _todaySunrise = result.sunrise;
          _todaySunset = result.sunset;
        }
        return _resultToData(result, date, timeFormat, locationLabel, _locationTier);
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

  DateTime? get todaySunrise => _todaySunrise;
  DateTime? get todaySunset => _todaySunset;
  DateTime? _todaySunrise;
  DateTime? _todaySunset;

  PanchangData _resultToData(
    PanchangResult result,
    DateTime date,
    DateFormat timeFormat,
    String? locationLabel,
    LocationTier tier,
  ) {
    String? brahmaMuhurta;
    if (result.sunrise != null) {
      final bm = result.sunrise!.subtract(const Duration(hours: 1, minutes: 36));
      brahmaMuhurta = timeFormat.format(bm);
    }

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
      gulikaKaalStart: result.gulikaKaal != null ? timeFormat.format(result.gulikaKaal!.start) : null,
      gulikaKaalEnd: result.gulikaKaal != null ? timeFormat.format(result.gulikaKaal!.end) : null,
      abhijitMahurtaStart: result.abhijitMuhurta != null ? timeFormat.format(result.abhijitMuhurta!.start) : null,
      abhijitMahurtaEnd: result.abhijitMuhurta != null ? timeFormat.format(result.abhijitMuhurta!.end) : null,
      auspiciousNote: _generateNote(result, brahmaMuhurta: brahmaMuhurta),
      locationLabel: locationLabel,
      brahmaMuhurta: brahmaMuhurta,
      accuracyTier: tier,
    );
  }

  Future<Position?> _getGpsLocation() async {
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
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('GPS Location error: $e');
      return null;
    }
  }

  /// IP-based geolocation fallback - no permission needed.
  /// Returns {lat, lng, city} or null if offline/failed.
  Future<Map<String, dynamic>?> _getIpLocation() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('http://ip.api.com/json/?fields=status,city,lat,lon'));
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] != 'success') return null;
      final lat = (json['lat'] as num?)?.toDouble();
      final lng = (json['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return {'lat': lat, 'lng': lng, 'city': json['city'] as String? ?? 'Unknown'};
    } catch (e) {
      debugPrint('IP geolocation error: $e');
      return null;
    }
  }

  String _generateNote(PanchangResult result, {String? brahmaMuhurta}) {
    final notes = <String>[];

    if (brahmaMuhurta != null) {
      notes.add('Best time for japa: $brahmaMuhurta (Brahma Muhurta).');
    }

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

    if (result.abhijitMuhurta != null) {
      final tf = DateFormat('hh:mm a');
      notes.add('Abhijit Muhurta: ${tf.format(result.abhijitMuhurta!.start)} - ${tf.format(result.abhijitMuhurta!.end)}) (always auspicious).');
    }

    if (notes.isEmpty) {
      notes.add('Continue your daily sadhana with devotion.');
    }

    return notes.join(' ');
  }
}

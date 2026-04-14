import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweph/sweph.dart';

class _BundleAssetLoader implements AssetLoader {
  @override
  Future<Uint8List> load(String assetPath) async {
    return (await rootBundle.load(assetPath)).buffer.asUint8List();
  }
}

class PanchangCalculator {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationSupportDirectory();
    await Sweph.init(
      epheAssets: [
        'packages/sweph/assets/ephe/sepl_18.se1',
        'packages/sweph/assets/ephe/semo_18.se1',
      ],
      epheFilesPath: '${dir.path}/ephe_files',
      assetLoader: _BundleAssetLoader(),
    );
    _initialized = true;
  }

  static double _normalize(double angle) {
    angle = angle % 360;
    return angle < 0 ? angle + 360 : angle;
  }

  static double _julianDay(DateTime dt) {
    final utc = dt.toUtc();
    final hour = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    return Sweph.swe_julday(
      utc.year, utc.month, utc.day, hour, CalendarType.SE_GREG_CAL,
    );
  }

  static double _getSiderealLongitude(DateTime dt, HeavenlyBody body) {
    final jd = _julianDay(dt);
    final result = Sweph.swe_calc_ut(jd, body, SwephFlag.SEFLG_SWIEPH);
    final tropicalLon = result.longitude;
    Sweph.swe_set_sid_mode(SiderealMode.SE_SIDM_LAHIRI, SiderealModeFlag.SE_SIDBIT_NONE, 0);
    final ayanamsa = Sweph.swe_get_ayanamsa_ut(jd);
    return _normalize(tropicalLon - ayanamsa);
  }

  static PanchangResult calculate(DateTime date, double latitude, double longitude) {
    final sunrise = _calculateSunrise(date, latitude, longitude);
    final sunset = _calculateSunset(date, latitude, longitude);

    final calcTime = sunrise ?? DateTime(date.year, date.month, date.day, 6);

    final sunLon = _getSiderealLongitude(calcTime, HeavenlyBody.SE_SUN);
    final moonLon = _getSiderealLongitude(calcTime, HeavenlyBody.SE_MOON);

    final tithi = _calculateTithi(sunLon, moonLon);
    final nakshatra = _calculateNakshatra(moonLon);
    final yoga = _calculateYoga(sunLon, moonLon);
    final karana = _calculateKarana(sunLon, moonLon);
    final vara = _calculateVara(date);
    final paksha = _calculatePaksha(sunLon, moonLon);
    final moonPhase = _calculateMoonPhase(sunLon, moonLon);
    final rahuKaal = _calculateRahuKaal(sunrise, sunset, date);
    final sunSign = _rashiNames[(sunLon / 30).floor()];
    final moonSign = _rashiNames[(moonLon / 30).floor()];

    final tithiTransition = _findTithiTransition(calcTime);
    final nakshatraTransition = _findNakshatraTransition(calcTime);
    final yogaTransition = _findYogaTransition(calcTime);
    final karanaTransition = _findKaranaTransition(calcTime);

    return PanchangResult(
      date: date,
      tithi: tithi,
      nakshatra: nakshatra,
      yoga: yoga,
      karana: karana,
      vara: vara,
      paksha: paksha,
      moonPhase: moonPhase,
      sunrise: sunrise,
      sunset: sunset,
      rahuKaal: rahuKaal,
      sunSign: sunSign,
      moonSign: moonSign,
      tithiTransition: tithiTransition,
      nakshatraTransition: nakshatraTransition,
      yogaTransition: yogaTransition,
      karanaTransition: karanaTransition,
    );
  }

  // --- Transition finders (bisection search) ---

  static TransitionInfo _findTithiTransition(DateTime calcTime) {
    double elongationAt(DateTime t) {
      final sun = _getSiderealLongitude(t, HeavenlyBody.SE_SUN);
      final moon = _getSiderealLongitude(t, HeavenlyBody.SE_MOON);
      return _normalize(moon - sun);
    }

    final elong = elongationAt(calcTime);
    final currentIdx = (elong / 12).floor();
    final nextBoundary = ((currentIdx + 1) * 12.0) % 360;

    final endTime = _bisectCrossing(
      calcTime,
      calcTime.add(const Duration(hours: 36)),
      (t) => elongationAt(t),
      nextBoundary,
      360,
    );

    final nextIdx = (currentIdx + 1) % 30;
    String nextName;
    if (nextIdx < 15) {
      nextName = nextIdx == 14 ? 'Purnima' : 'Shukla ${_tithiNames[nextIdx]}';
    } else {
      final dn = nextIdx - 15;
      nextName = dn == 14 ? 'Amavasya' : 'Krishna ${_tithiNames[dn]}';
    }

    return TransitionInfo(endTime: endTime, nextName: nextName);
  }

  static TransitionInfo _findNakshatraTransition(DateTime calcTime) {
    const width = 360.0 / 27;

    double moonLonAt(DateTime t) =>
        _getSiderealLongitude(t, HeavenlyBody.SE_MOON);

    final moonLon = moonLonAt(calcTime);
    final currentIdx = (moonLon / width).floor();
    final nextBoundary = ((currentIdx + 1) * width) % 360;

    final endTime = _bisectCrossing(
      calcTime,
      calcTime.add(const Duration(hours: 36)),
      moonLonAt,
      nextBoundary,
      360,
    );

    final nextIdx = (currentIdx + 1) % 27;
    return TransitionInfo(endTime: endTime, nextName: _nakshatraNames[nextIdx]);
  }

  static TransitionInfo _findYogaTransition(DateTime calcTime) {
    const width = 360.0 / 27;

    double yogaSumAt(DateTime t) {
      final sun = _getSiderealLongitude(t, HeavenlyBody.SE_SUN);
      final moon = _getSiderealLongitude(t, HeavenlyBody.SE_MOON);
      return _normalize(sun + moon);
    }

    final sum = yogaSumAt(calcTime);
    final currentIdx = (sum / width).floor().clamp(0, 26);
    final nextBoundary = ((currentIdx + 1) * width) % 360;

    final endTime = _bisectCrossing(
      calcTime,
      calcTime.add(const Duration(hours: 36)),
      yogaSumAt,
      nextBoundary,
      360,
    );

    final nextIdx = (currentIdx + 1) % 27;
    return TransitionInfo(endTime: endTime, nextName: _yogaNames[nextIdx]);
  }

  static TransitionInfo _findKaranaTransition(DateTime calcTime) {
    double elongationAt(DateTime t) {
      final sun = _getSiderealLongitude(t, HeavenlyBody.SE_SUN);
      final moon = _getSiderealLongitude(t, HeavenlyBody.SE_MOON);
      return _normalize(moon - sun);
    }

    final elong = elongationAt(calcTime);
    final currentIdx = (elong / 6).floor();
    final nextBoundary = ((currentIdx + 1) * 6.0) % 360;

    final endTime = _bisectCrossing(
      calcTime,
      calcTime.add(const Duration(hours: 18)),
      elongationAt,
      nextBoundary,
      360,
    );

    final nextIdx = (currentIdx + 1) % 60;
    String nextName;
    if (nextIdx == 0) {
      nextName = 'Kimstughna';
    } else if (nextIdx < 58) {
      nextName = _movableKaranas[(nextIdx - 1) % 7];
    } else if (nextIdx == 58) {
      nextName = 'Shakuni';
    } else if (nextIdx == 59) {
      nextName = 'Chatushpada';
    } else {
      nextName = 'Naga';
    }

    return TransitionInfo(endTime: endTime, nextName: nextName);
  }

  /// Binary search for the moment a cyclical value crosses [targetDeg].
  static DateTime _bisectCrossing(
    DateTime start,
    DateTime end,
    double Function(DateTime) valueFn,
    double targetDeg,
    double cycle,
  ) {
    var lo = start.millisecondsSinceEpoch;
    var hi = end.millisecondsSinceEpoch;

    double distAfterTarget(double val) {
      return _normalize(val - targetDeg) > 0 && _normalize(val - targetDeg) < cycle / 2
          ? _normalize(val - targetDeg)
          : -(cycle - _normalize(val - targetDeg));
    }

    final startSign = distAfterTarget(valueFn(start)) >= 0;

    for (int i = 0; i < 30; i++) {
      final mid = (lo + hi) ~/ 2;
      final midTime = DateTime.fromMillisecondsSinceEpoch(mid);
      final midSign = distAfterTarget(valueFn(midTime)) >= 0;

      if (midSign == startSign) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch((lo + hi) ~/ 2);
  }

  // --- Tithi ---

  static TithiResult _calculateTithi(double sunLon, double moonLon) {
    final elongation = _normalize(moonLon - sunLon);
    const tithiLength = 12.0;
    final tithiNum = (elongation / tithiLength).floor() + 1;
    final percentage = ((elongation % tithiLength) / tithiLength) * 100;

    String name;
    int displayNum;
    bool isWaxing;

    if (tithiNum <= 15) {
      isWaxing = true;
      displayNum = tithiNum;
      name = tithiNum == 15 ? 'Purnima' : 'Shukla ${_tithiNames[tithiNum - 1]}';
    } else {
      isWaxing = false;
      displayNum = tithiNum - 15;
      name = displayNum == 15 ? 'Amavasya' : 'Krishna ${_tithiNames[displayNum - 1]}';
    }

    return TithiResult(
      number: displayNum,
      name: name,
      percentage: percentage,
      isWaxing: isWaxing,
    );
  }

  // --- Nakshatra ---

  static NakshatraResult _calculateNakshatra(double moonLon) {
    const nakshatraWidth = 360.0 / 27;
    final idx = (moonLon / nakshatraWidth).floor();
    final remainder = moonLon % nakshatraWidth;
    final pada = (remainder / (nakshatraWidth / 4)).floor() + 1;

    return NakshatraResult(
      number: idx + 1,
      name: _nakshatraNames[idx],
      pada: pada,
    );
  }

  // --- Yoga ---

  static YogaResult _calculateYoga(double sunLon, double moonLon) {
    final sum = _normalize(sunLon + moonLon);
    const yogaWidth = 360.0 / 27;
    final idx = (sum / yogaWidth).floor().clamp(0, 26);

    return YogaResult(number: idx + 1, name: _yogaNames[idx]);
  }

  // --- Karana ---

  static KaranaResult _calculateKarana(double sunLon, double moonLon) {
    final elongation = _normalize(moonLon - sunLon);
    final karanaIdx = (elongation / 6).floor();

    String name;
    if (karanaIdx == 0) {
      name = 'Kimstughna';
    } else if (karanaIdx < 58) {
      name = _movableKaranas[(karanaIdx - 1) % 7];
    } else if (karanaIdx == 58) {
      name = 'Shakuni';
    } else if (karanaIdx == 59) {
      name = 'Chatushpada';
    } else {
      name = 'Naga';
    }

    return KaranaResult(number: karanaIdx + 1, name: name);
  }

  // --- Vara ---

  static String _calculateVara(DateTime date) {
    return _varaNames[date.weekday % 7];
  }

  // --- Paksha ---

  static String _calculatePaksha(double sunLon, double moonLon) {
    final elongation = _normalize(moonLon - sunLon);
    return elongation < 180 ? 'Shukla Paksha' : 'Krishna Paksha';
  }

  // --- Moon Phase ---

  static String _calculateMoonPhase(double sunLon, double moonLon) {
    final elongation = _normalize(moonLon - sunLon);
    if (elongation < 45) return 'New Moon';
    if (elongation < 90) return 'Waxing Crescent';
    if (elongation < 135) return 'First Quarter';
    if (elongation < 180) return 'Waxing Gibbous';
    if (elongation < 225) return 'Full Moon';
    if (elongation < 270) return 'Waning Gibbous';
    if (elongation < 315) return 'Last Quarter';
    return 'Waning Crescent';
  }

  // --- Rahu Kaal ---

  // Standard Rahu Kaal periods (0-indexed eighths of daylight)
  // Verified against Drik Panchang: drikpanchang.com
  // Sun=7, Mon=1, Tue=6, Wed=4, Thu=5, Fri=3, Sat=2
  static RahuKaalResult? _calculateRahuKaal(DateTime? sunrise, DateTime? sunset, DateTime date) {
    if (sunrise == null || sunset == null) return null;
    final dayLen = sunset.difference(sunrise).inMilliseconds;
    final oneEighth = dayLen ~/ 8;
    const periods = [7, 1, 6, 4, 5, 3, 2]; // Sun=0..Sat=6
    final dayOfWeek = date.weekday % 7;
    final start = sunrise.add(Duration(milliseconds: periods[dayOfWeek] * oneEighth));
    final end = start.add(Duration(milliseconds: oneEighth));
    return RahuKaalResult(start: start, end: end);
  }

  // --- Sunrise/Sunset (NOAA algorithm) ---

  static DateTime? _calculateSunrise(DateTime date, double lat, double lng) {
    return _calcSunEvent(date, lat, lng, isSunrise: true);
  }

  static DateTime? _calculateSunset(DateTime date, double lat, double lng) {
    return _calcSunEvent(date, lat, lng, isSunrise: false);
  }

  static DateTime? _calcSunEvent(DateTime date, double lat, double lng, {required bool isSunrise}) {
    final year = date.year;
    final month = date.month;
    final day = date.day;

    final n1 = (275 * month / 9).floor();
    final n2 = ((month + 9) / 12).floor();
    final n3 = 1 + ((year - 4 * (year / 4).floor() + 2) / 3).floor();
    final n = n1 - (n2 * n3) + day - 30;

    final lngHour = lng / 15;
    final t = n + ((isSunrise ? 6 : 18) - lngHour) / 24;

    final mDeg = (0.9856 * t) - 3.289;
    final mRad = mDeg * pi / 180;

    var lDeg = mDeg + (1.916 * sin(mRad)) + (0.020 * sin(2 * mRad)) + 282.634;
    lDeg = lDeg % 360;
    if (lDeg < 0) lDeg += 360;

    var ra = atan(0.91764 * tan(lDeg * pi / 180)) * 180 / pi;
    ra = ra % 360;
    if (ra < 0) ra += 360;

    final lQ = (lDeg / 90).floor() * 90;
    final raQ = (ra / 90).floor() * 90;
    ra = ra + (lQ - raQ);
    ra = ra / 15;

    final sinDec = 0.39782 * sin(lDeg * pi / 180);
    final cosDec = cos(asin(sinDec));

    final cosH = (cos(90.833 * pi / 180) - (sinDec * sin(lat * pi / 180))) /
        (cosDec * cos(lat * pi / 180));

    if (cosH > 1 || cosH < -1) return null;

    double h;
    if (isSunrise) {
      h = 360 - (acos(cosH) * 180 / pi);
    } else {
      h = acos(cosH) * 180 / pi;
    }

    final tFinal = h / 15 + ra - (0.06571 * t) - 6.622;
    var ut = tFinal - lngHour;
    ut = ut % 24;
    if (ut < 0) ut += 24;

    final hours = ut.floor();
    final minutes = ((ut - hours) * 60).floor();
    final seconds = (((ut - hours) * 60 - minutes) * 60).floor();

    final utcResult = DateTime.utc(year, month, day, hours, minutes, seconds);
    return utcResult.toLocal();
  }

  // --- Name Tables ---

  static const _tithiNames = [
    'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami',
    'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami',
    'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi', 'Purnima',
  ];

  static const _nakshatraNames = [
    'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
    'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'Purva Phalguni', 'Uttara Phalguni',
    'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha', 'Jyeshtha',
    'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishtha', 'Shatabhisha',
    'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati',
  ];

  static const _yogaNames = [
    'Vishkumbha', 'Preeti', 'Ayushman', 'Saubhagya', 'Shobhana', 'Atiganda',
    'Sukarman', 'Dhriti', 'Shoola', 'Ganda', 'Vriddhi', 'Dhruva',
    'Vyaghata', 'Harshana', 'Vajra', 'Siddhi', 'Vyatipata', 'Variyan',
    'Parigha', 'Shiva', 'Siddha', 'Sadhya', 'Shubha', 'Shukla',
    'Brahma', 'Indra', 'Vaidhriti',
  ];

  static const _movableKaranas = [
    'Bava', 'Balava', 'Kaulava', 'Taitila', 'Gara', 'Vanija', 'Vishti',
  ];

  static const _varaNames = [
    'Sunday (Ravivar)', 'Monday (Somvar)', 'Tuesday (Mangalvar)',
    'Wednesday (Budhvar)', 'Thursday (Guruvar)', 'Friday (Shukravar)',
    'Saturday (Shanivar)',
  ];

  static const _rashiNames = [
    'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya',
    'Tula', 'Vrischika', 'Dhanus', 'Makara', 'Kumbha', 'Meena',
  ];
}

// --- Result Models ---

class PanchangResult {
  final DateTime date;
  final TithiResult tithi;
  final NakshatraResult nakshatra;
  final YogaResult yoga;
  final KaranaResult karana;
  final String vara;
  final String paksha;
  final String moonPhase;
  final DateTime? sunrise;
  final DateTime? sunset;
  final RahuKaalResult? rahuKaal;
  final String sunSign;
  final String moonSign;
  final TransitionInfo tithiTransition;
  final TransitionInfo nakshatraTransition;
  final TransitionInfo yogaTransition;
  final TransitionInfo karanaTransition;

  const PanchangResult({
    required this.date,
    required this.tithi,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.vara,
    required this.paksha,
    required this.moonPhase,
    required this.sunrise,
    required this.sunset,
    required this.rahuKaal,
    required this.sunSign,
    required this.moonSign,
    required this.tithiTransition,
    required this.nakshatraTransition,
    required this.yogaTransition,
    required this.karanaTransition,
  });
}

class TransitionInfo {
  final DateTime endTime;
  final String nextName;

  const TransitionInfo({required this.endTime, required this.nextName});
}

class TithiResult {
  final int number;
  final String name;
  final double percentage;
  final bool isWaxing;

  const TithiResult({
    required this.number,
    required this.name,
    required this.percentage,
    required this.isWaxing,
  });
}

class NakshatraResult {
  final int number;
  final String name;
  final int pada;

  const NakshatraResult({
    required this.number,
    required this.name,
    required this.pada,
  });
}

class YogaResult {
  final int number;
  final String name;

  const YogaResult({required this.number, required this.name});
}

class KaranaResult {
  final int number;
  final String name;

  const KaranaResult({required this.number, required this.name});
}

class RahuKaalResult {
  final DateTime start;
  final DateTime end;

  const RahuKaalResult({required this.start, required this.end});
}

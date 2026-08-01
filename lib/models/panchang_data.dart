enum LocationTier {
  gps, // GPS/device location - ±5-15 sec accuracy
  ip, // IP-based geolocation - ±1-3 min accuracy
  fallback, // Default city (New Delhi) - may differ significantly
}

class PanchangData {
  final String date;
  final String tithi;
  final String? tithiEndTime;
  final String? nextTithi;
  final String nakshatra;
  final String nakshatraPada;
  final String? nakshatraEndTime;
  final String? nextNakshatra;
  final String vaar;
  final String yoga;
  final String? yogaEndTime;
  final String? nextYoga;
  final String karana;
  final String? karanaEndTime;
  final String? nextKarana;
  final String sunrise;
  final String sunset;
  final String paksha;
  final String moonPhase;
  final String sunSign;
  final String moonSign;
  final String? rahuKaalStart;
  final String? rahuKaalEnd;
  final String? gulikaKaalStart;
  final String? gulikaKaalEnd;
  final String? abhijitMahurtaStart;
  final String? abhijitMahurtaEnd;
  final String auspiciousNote;
  final String? locationLabel;
  final String? brahmaMuhurta;
  final String? masaPurnimant;
  final String? masaAmant;
  final LocationTier accuracyTier;

  const PanchangData({
    required this.date,
    required this.tithi,
    this.tithiEndTime,
    this.nextTithi,
    required this.nakshatra,
    required this.nakshatraPada,
    this.nakshatraEndTime,
    this.nextNakshatra,
    required this.vaar,
    required this.yoga,
    this.yogaEndTime,
    this.nextYoga,
    required this.karana,
    this.karanaEndTime,
    this.nextKarana,
    required this.sunrise,
    required this.sunset,
    required this.paksha,
    required this.moonPhase,
    required this.sunSign,
    required this.moonSign,
    this.rahuKaalStart,
    this.rahuKaalEnd,
    this.gulikaKaalStart,
    this.gulikaKaalEnd,
    this.abhijitMahurtaStart,
    this.abhijitMahurtaEnd,
    required this.auspiciousNote,
    this.locationLabel,
    this.brahmaMuhurta,
    this.masaPurnimant,
    this.masaAmant,
    this.accuracyTier = LocationTier.fallback,
  });

  static PanchangData placeholder(String date, {String? locationLabel}) =>
      PanchangData(
        date: date,
        tithi: '—',
        nakshatra: '—',
        nakshatraPada: '—',
        vaar: '—',
        yoga: '—',
        karana: '—',
        sunrise: '—',
        sunset: '—',
        paksha: '—',
        moonPhase: '—',
        sunSign: '—',
        moonSign: '—',
        auspiciousNote:
            'Could not calculate panchang. Please enable location access.',
        locationLabel: locationLabel,
        accuracyTier: LocationTier.fallback,
      );
}

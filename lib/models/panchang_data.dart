class PanchangData {
  final String date;
  final String tithi;
  final String nakshatra;
  final String vaar;
  final String yoga;
  final String karana;
  final String sunrise;
  final String sunset;
  final String auspiciousNote;

  const PanchangData({
    required this.date,
    required this.tithi,
    required this.nakshatra,
    required this.vaar,
    required this.yoga,
    required this.karana,
    required this.sunrise,
    required this.sunset,
    required this.auspiciousNote,
  });

  factory PanchangData.fromMap(Map<String, dynamic> map) => PanchangData(
        date: map['date'] as String? ?? '',
        tithi: map['tithi'] as String? ?? '—',
        nakshatra: map['nakshatra'] as String? ?? '—',
        vaar: map['vaar'] as String? ?? '—',
        yoga: map['yoga'] as String? ?? '—',
        karana: map['karana'] as String? ?? '—',
        sunrise: map['sunrise'] as String? ?? '—',
        sunset: map['sunset'] as String? ?? '—',
        auspiciousNote: map['auspicious_note'] as String? ?? '',
      );

  static PanchangData placeholder(String date) => PanchangData(
        date: date,
        tithi: '—',
        nakshatra: '—',
        vaar: '—',
        yoga: '—',
        karana: '—',
        sunrise: '—',
        sunset: '—',
        auspiciousNote: 'Panchang data not available for this date.',
      );
}

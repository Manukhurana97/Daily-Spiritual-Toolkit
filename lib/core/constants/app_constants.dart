class AppConstants {
  AppConstants._();

  static const String appName = 'Nitya Sadhana';
  static const String tagline =
      'Your daily spiritual toolkit — japa counter,\npanchang, and direction compass.';

  static const int defaultMalaSize = 108;
  static const int maxMantras = 50;

  /// Dynamic anti-spam: two-tier formula based on mantra text length.
  /// Naam (≤15 chars): chars * 40ms - fast tapping for short names.
  /// mantra (>15 chars): chars * 80ms - realistic pace for spoken mantras
  ///
  /// "Ram"               (3)  ->  150ms -> ~6.7/sec
  /// "Radha"             (5)  ->  200ms -> ~5/sec
  /// "Krishna"           (7)  ->  280ms -> ~3.6/sec
  /// "On Namah Shivaya"  (17) ->  1360ms -> ~0.7/sec
  /// Gayatri             (86) ->  6960ms -> ~0.14/sec
  /// "Maha Mrityunjaya   (95) ->  7600ms -> ~0.13/sec
  static Duration antiSpanInterval(int mantraTextLabel) {
    final ms = mantraTextLabel <= 15
        ? (mantraTextLabel * 40).clamp(150, 600)
        : (mantraTextLabel * 80).clamp(600, 8000);
    return Duration(milliseconds: ms);
  }

  static const List<String> defaultMantras = ['Radha', 'Ram', 'Krishna'];

  static const List<int> malaSizePresents = [27, 54, 108, 1008];
}

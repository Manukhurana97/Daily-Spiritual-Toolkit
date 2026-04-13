class AppConstants {
  AppConstants._();

  static const String appName = 'Naam Jap';
  static const String tagline =
      'Count your naam-jap, follow the right panchang,\nand face the right direction.';

  static const int malaSize = 108;
  static const int maxMantras = 3;

  static const Duration antiSpamInterval = Duration(milliseconds: 300);

  static const int maxTapsPerSecond = 10;

  static const List<String> defaultMantras = [
    'Radha',
    'Ram',
    'Krishna',
  ];
}

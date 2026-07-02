class AppConstants {
  AppConstants._();

  static const String appName = 'Nitya Sadhana';
  static const String tagline =
      'Your daily spiritual toolkit — japa counter,\npanchang, and direction compass.';

  static const int malaSize = 108;
  static const int maxMantras = 3;

  static const Duration antiSpamInterval = Duration(milliseconds: 300);

  static const List<String> defaultMantras = [
    'Radha',
    'Ram',
    'Krishna',
  ];
}

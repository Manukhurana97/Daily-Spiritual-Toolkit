# Nitya Sadhana

**Your daily spiritual toolkit — japa counter, panchang, and direction compass.**

A beautiful, offline-first Flutter app designed for daily Hindu spiritual practice. Built with accuracy and devotion in mind.

**Version:** 1.0.0

---

## Features

### Japa Counter

- Tap-based mantra counting with a visual mala progress ring (108 beads per mala)
- Support for multiple mantras — add up to 3 custom mantras, rename, or remove them
- Seamless mantra switching mid-session without losing count (in-memory session preservation)
- End Session to save counts to the database; Reset to clear without saving
- Per-mantra statistics: today's count, total count, completed malas, and last session summary
- Haptic feedback on each accepted tap
- Anti-spam tap throttling (300ms debounce)

### Panchang (Hindu Calendar)

- **Fully offline** — all astronomical calculations done on-device using Swiss Ephemeris (`sweph`)
- **Location-aware** — uses device GPS for accurate sunrise/sunset and all derived timings
- Falls back to New Delhi (28.6°N, 77.2°E) with a visible badge if location is unavailable
- **7-day view** — swipeable horizontal day cards (today + next 6 days)
- **Panchang elements** with transition times (like Drik Panchang):
  - **Tithi** — with end time and next tithi (e.g., "Trayodashi upto 10:31 PM → Chaturdashi")
  - **Nakshatra** — with pada and end time
  - **Yoga** — with end time
  - **Karana** — with end time
- Sunrise and Sunset (NOAA solar algorithm)
- Rahu Kaal (standard Drik Panchang periods)
- Paksha (Shukla / Krishna)
- Moon Phase
- Sun Sign and Moon Sign (sidereal/Lahiri ayanamsa)
- Contextual auspicious notes (Ekadashi, Purnima, Amavasya, Shivratri, day-specific guidance)

### Compass

- Real-time direction compass using device magnetometer
- East-facing detection with a banner when aligned (ideal for puja)
- Compass rose with heading in degrees and cardinal direction label
- Calibration overlay with figure-8 animation when sensor accuracy is low

### Settings

- Mantra management (add, rename, remove, set default)
- Language display (follows system locale)
- Reset all data (clears database and preferences with confirmation)
- About section with app info and privacy note

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Dart) |
| State Management | Riverpod (`flutter_riverpod`) |
| Local Database | SQLite (`sqflite`) |
| Preferences | `shared_preferences` |
| Astronomy Engine | Swiss Ephemeris (`sweph`) — Lahiri ayanamsa, sidereal calculations |
| Location | `geolocator` |
| Compass | `flutter_compass` |
| Date Formatting | `intl` |
| Permissions | `permission_handler` |

---

## Architecture

```
lib/
├── main.dart                  # App entry, splash, provider initialization
├── app.dart                   # MaterialApp + theme configuration
├── core/
│   ├── constants/             # App constants (mala size, max mantras, etc.)
│   ├── database/              # SQLite database helper
│   └── theme/                 # AppColors, light theme
├── models/
│   ├── mantra.dart            # Mantra model
│   ├── japa_session.dart      # Session DB model
│   ├── japa_stats.dart        # Aggregated stats model
│   └── panchang_data.dart     # Panchang display model
├── providers/
│   ├── japa_provider.dart     # Japa counting, sessions, stats
│   ├── panchang_provider.dart # 7-day panchang, location, formatting
│   ├── compass_provider.dart  # Magnetometer stream, calibration
│   └── settings_provider.dart # Preferences (default mantra, locale)
├── services/
│   └── panchang_calculator.dart  # Swiss Ephemeris calculations + NOAA sunrise/sunset
├── screens/
│   ├── home_shell.dart        # Bottom nav shell (4 tabs)
│   ├── japa/                  # Japa counter screen
│   ├── panchang/              # Panchang screen
│   ├── compass/               # Compass screen
│   └── settings/              # Settings screen
└── widgets/                   # Shared UI components
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.11.4+
- Xcode (for iOS)
- Android Studio (for Android)

### Run

```bash
flutter pub get
flutter run
```

### Build

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

---

## Permissions

| Permission | Platform | Purpose |
|------------|----------|---------|
| Location (when in use) | iOS, Android | Accurate sunrise/sunset and panchang timings |
| Magnetometer / Sensors | iOS, Android | Compass heading |

---

## Design

- Warm cream (#FFF8F0) background with saffron and deep maroon accents
- Consistent look across iOS and Android (light theme forced in both day/night modes)
- Portrait-only orientation
- Branded splash screen during initialization

---

## License

Private — all rights reserved.

class Mantra {
  final int? id;
  final String name;
  final String? actualMantra;
  final String? targetDirection;
  final DateTime createdAt;
  final int? tapSpeedMs;
  final double? avgTapMs;
  final int tapSampleCount;
  final String activeDays; // 'all' or comma-separated: 'mon,tue,fri'
  final String bestTime; // 'anytime', 'morning, 'evening'

  const Mantra({
    this.id,
    required this.name,
    this.actualMantra,
    this.targetDirection,
    required this.createdAt,
    this.tapSpeedMs,
    this.avgTapMs,
    this.tapSampleCount = 0,
    this.activeDays = 'all',
    this.bestTime = 'anytime',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'actual_mantra': actualMantra,
        'target_direction': targetDirection,
        'created_at': createdAt.toIso8601String(),
        'tap_speed_ms': tapSpeedMs,
        'avg_tap_ms': avgTapMs,
        'tap_sample_count': tapSampleCount,
        'active_days': activeDays,
        'best_time': bestTime
      };

  factory Mantra.fromMap(Map<String, dynamic> map) => Mantra(
        id: map['id'] as int,
        name: map['name'] as String,
        actualMantra: map['actual_mantra'] as String?,
        targetDirection: map['target_direction'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        tapSpeedMs: map['tap_speed_ms'] as int?,
        avgTapMs: (map['avg_tap_ms'] as num?)?.toDouble(),
        tapSampleCount: (map['tap_sample_count'] as int?) ?? 0,
        activeDays: (map['active_days'] as String?) ?? 'all',
        bestTime: (map['best_time'] as String?) ?? 'anytime',
      );

  /// Day codes used in activeDays
  static const allDayCodes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const dayLabels = {
    'mon': 'Mon', 'tue' : 'Tue', 'wed': 'Wed', 'thu': 'Thu',
    'fri': 'Fri', 'sat': 'Sat', 'sun' : 'Sun',
  };

  List<String> get activeDayList =>
    activeDays == 'all' ? allDayCodes : activeDays.split(',');

  bool get isActiveToday {
    final weekDay = DateTime.now().weekday; // 1=Mon ... 7=Sun
    final todayCode = allDayCodes[weekDay - 1];
    return activeDays == 'all' || activeDayList.contains(todayCode);
  }

  String get activeDayDisplay {
    if (activeDays == 'all') return 'Every day';
    final days = activeDayList;
    if (days.length == 7) return 'Every Day';
    return days.map((d) => dayLabels[d] ?? d).join(', ');
  }

  String get bestTimeDisplay {
    switch (bestTime) {
      case 'morning': return 'Morning';
      case 'evening': return 'Evening';
      default: return 'Anytime';
    }
  }

  IconLabel get bestTimeIcon {
    switch (bestTime) {
      case 'morning': return const IconLabel(0xe518, 'Morning');
      case 'evening': return const IconLabel(0xf6bf, 'Evening');
      default: return const IconLabel(0xe07f, 'Anytime');
    }
  }

  Mantra copyWith({
    int? id,
    String? name,
    String? actualMantra,
    String? targetDirection,
    DateTime? createdAt,
    int? tapSpeedMs,
    double? avgTapMS,
    int? tapSampleCount,
    String? activeDays,
    String? bestTime,
    bool clearActualMantra = false,
    bool clearTargetDirection = false,
    bool clearTapSpeed = false,
  }) =>
      Mantra(
        id: id ?? this.id,
        name: name ?? this.name,
        actualMantra: clearActualMantra ? null : (actualMantra ?? this.actualMantra),
        targetDirection: clearTargetDirection ? null : (targetDirection ?? this.targetDirection),
        createdAt: createdAt ?? this.createdAt,
        tapSpeedMs: clearTapSpeed ? null : (tapSpeedMs ?? this.tapSpeedMs),
        avgTapMs: avgTapMs ?? this.avgTapMs,
        tapSampleCount: tapSampleCount ?? this.tapSampleCount,
        activeDays: activeDays ?? this.activeDays,
        bestTime: bestTime ?? this.bestTime
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Mantra && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class IconLabel {
  final int codePoint;
  final String label;
  const IconLabel(this.codePoint, this.label);
}
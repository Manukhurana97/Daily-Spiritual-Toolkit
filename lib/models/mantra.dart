class Mantra {
  final int? id;
  final String name;
  final String? actualMantra;
  final String? targetDirection;
  final DateTime createdAt;
  final int? tapSpeedMs;
  final double? avgTapMs;
  final int tapSampleCount;

  const Mantra({
    this.id,
    required this.name,
    this.actualMantra,
    this.targetDirection,
    required this.createdAt,
    this.tapSpeedMs,
    this.avgTapMs,
    this.tapSampleCount = 0
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'actual_mantra': actualMantra,
        'target_direction': targetDirection,
        'created_at': createdAt.toIso8601String(),
        'tap_speed_ms': tapSpeedMs,
        'avg_tap_ms': avgTapMs,
        'tap_sample_count': tapSampleCount
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
      );

  Mantra copyWith({
    int? id,
    String? name,
    String? actualMantra,
    String? targetDirection,
    DateTime? createdAt,
    int? tapSpeedMs,
    double? avgTapMS,
    int? tapSampleCount,
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
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Mantra && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class Mantra {
  final int? id;
  final String name;
  final String? actualMantra;
  final String? targetDirection;
  final DateTime createdAt;

  const Mantra({
    this.id,
    required this.name,
    this.actualMantra,
    this.targetDirection,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'actual_mantra': actualMantra,
        'target_direction': targetDirection,
        'created_at': createdAt.toIso8601String(),
      };

  factory Mantra.fromMap(Map<String, dynamic> map) => Mantra(
        id: map['id'] as int,
        name: map['name'] as String,
        actualMantra: map['actual_mantra'] as String?,
        targetDirection: map['target_direction'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Mantra copyWith({
    int? id,
    String? name,
    String? actualMantra,
    String? targetDirection,
    DateTime? createdAt,
    bool clearActualMantra = false,
    bool clearTargetDirection = false,
  }) =>
      Mantra(
        id: id ?? this.id,
        name: name ?? this.name,
        actualMantra: clearActualMantra ? null : (actualMantra ?? this.actualMantra),
        targetDirection: clearTargetDirection ? null : (targetDirection ?? this.targetDirection),
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Mantra && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

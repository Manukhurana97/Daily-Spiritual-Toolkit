class Sankalp {
  final int? id;
  final int mantraId;
  final int totalGoal;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Sankalp({
    this.id,
    required this.mantraId,
    required this.totalGoal,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.completedAt,
  });

  bool get isComplete => completedAt != null;
  int get totalDays => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'mantra_id': mantraId,
        'total_goal': totalGoal,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory Sankalp.fromMap(Map<String, dynamic> map) => Sankalp(
        id: map['id'] as int,
        mantraId: map['mantra_id'] as int,
        totalGoal: map['total_goal'] as int,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
      );

  Sankalp copyWith({DateTime? completedAt}) => Sankalp(
        id: id,
        mantraId: mantraId,
        totalGoal: totalGoal,
        startDate: startDate,
        endDate: endDate,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

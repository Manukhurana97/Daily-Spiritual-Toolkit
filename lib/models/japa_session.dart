class JapaSession {
  final int? id;
  final int mantraId;
  final int count;
  final DateTime startedAt;
  final DateTime endedAt;

  const JapaSession({
    this.id,
    required this.mantraId,
    required this.count,
    required this.startedAt,
    required this.endedAt,
  });

  Duration get duration => endedAt.difference(startedAt);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'mantra_id': mantraId,
        'count': count,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
      };

  factory JapaSession.fromMap(Map<String, dynamic> map) => JapaSession(
        id: map['id'] as int,
        mantraId: map['mantra_id'] as int,
        count: map['count'] as int,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: DateTime.parse(map['ended_at'] as String),
      );
}

class JapaStats {
  final int todayCount;
  final int totalCount;
  final int todayMalas;
  final int totalMalas;
  final LastSessionInfo? lastSession;

  const JapaStats({
    required this.todayCount,
    required this.totalCount,
    required this.todayMalas,
    required this.totalMalas,
    this.lastSession,
  });

  static const empty = JapaStats(
    todayCount: 0,
    totalCount: 0,
    todayMalas: 0,
    totalMalas: 0,
  );
}

class LastSessionInfo {
  final int count;
  final Duration duration;
  final DateTime endedAt;

  const LastSessionInfo({
    required this.count,
    required this.duration,
    required this.endedAt,
  });
}

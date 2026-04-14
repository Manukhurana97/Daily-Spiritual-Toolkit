import 'dart:math';

import '../models/sankalp.dart';

class SankalpEngine {
  final Sankalp sankalp;
  final int completedCount;

  const SankalpEngine({required this.sankalp, required this.completedCount});

  int get remainingChants => max(0, sankalp.totalGoal - completedCount);

  int get remainingDays {
    final days = sankalp.endDate.difference(DateTime.now()).inDays + 1;
    return max(1, days);
  }

  int get elapsedDays {
    final days = DateTime.now().difference(sankalp.startDate).inDays + 1;
    return min(days, sankalp.totalDays);
  }

  int get dailyRequired => (remainingChants / remainingDays).ceil();
  int get dailyRequiredRounds => (dailyRequired / 108).ceil();
  double get progressFraction => min(1.0, completedCount / sankalp.totalGoal);
  bool get isComplete => completedCount >= sankalp.totalGoal;
  bool get isOverdue => DateTime.now().isAfter(sankalp.endDate) && !isComplete;

  bool get isOnTrack {
    final expectedByNow = (sankalp.totalGoal * elapsedDays / sankalp.totalDays).ceil();
    return completedCount >= expectedByNow;
  }

  String get statusLabel {
    if (isComplete) return 'Completed';
    if (isOverdue) return 'Overdue';
    if (isOnTrack) return 'On Track';
    return 'Behind';
  }
}

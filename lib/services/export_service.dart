import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';

class ExportService {
  /// Returns a status message suitable for displaying in a SnackBar.
  static Future<String> exportSessions({
    int? mantraId,
    String mantraName = 'All',
  }) async {
    try {
      final sessions = await AppDatabase.getAllSessions(mantraId: mantraId);
      if (sessions.isEmpty) return 'No session to export';

      final dateFormat = DateFormat('yyyy-MM-dd');
      final timeFormat = DateFormat('HH:mm:ss');

      final rows = <List<String>>[
        ['Mantra', 'Count', 'Date', 'Start Time', 'End Time', 'Duration (min)'],
        ...sessions.map((s) =>
        [
          mantraName,
          '${s.count}',
          dateFormat.format(s.startedAt),
          timeFormat.format(s.startedAt),
          timeFormat.format(s.endedAt),
          '${s.duration.inMinutes}',
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/japa_export_${dateFormat.format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
          [XFile(file.path)], subject: 'Japa History Export');
      return 'Export ready - ${sessions.length} sessions.';
    } catch (e) {
        debugPrint('Export error: $e');
        return 'Export failed. Please try again';
    }
  }
}

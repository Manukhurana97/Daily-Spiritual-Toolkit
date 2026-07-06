import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/mantra.dart';
import '../models/japa_session.dart';
import '../models/sankalp.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'naam_jap.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mantras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            actual_mantra TEXT,
            target_direction TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE japa_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mantra_id INTEGER NOT NULL,
            count INTEGER NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL,
            FOREIGN KEY (mantra_id) REFERENCES mantras(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE sankalps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mantra_id INTEGER NOT NULL,
            total_goal INTEGER NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            completed_at TEXT,
            mode TEXT NOT NULL DEFAULT 'daily',
            FOREIGN KEY (mantra_id) REFERENCES mantras(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE mantras ADD COLUMN actual_mantra TEXT');
          await db.execute('ALTER TABLE mantras ADD COLUMN target_direction TEXT');
          await db.execute('''
            CREATE TABLE sankalps (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              mantra_id INTEGER NOT NULL,
              total_goal INTEGER NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              created_at TEXT NOT NULL,
              completed_at TEXT,
              mode TEXT NOT NULL DEFAULT 'daily',
              FOREIGN KEY (mantra_id) REFERENCES mantras(id)
            )
          ''');
        }
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE sankalp ADD COLUMN mode TEXT NOT NULL DEFAULT 'daily");
          } catch(_) {
            // column may already exist
          }
        }
      },
    );
  }

  // ── Mantras ──

  static Future<List<Mantra>> getMantras() async {
    final db = await instance;
    final rows = await db.query('mantras', orderBy: 'created_at ASC');
    return rows.map(Mantra.fromMap).toList();
  }

  static Future<Mantra> insertMantra(
      String name, {
        String? actualMantra,
        String? targetDirection
      }) async {
    final db = await instance;
    final mantra = Mantra(
        name: name,
        actualMantra: actualMantra,
        targetDirection: targetDirection,
        createdAt: DateTime.now()
    );
    final id = await db.insert('mantras', mantra.toMap());
    return mantra.copyWith(id: id);
  }

  static Future<void> deleteMantra(int id) async {
    final db = await instance;
    await db.delete('sankalps', where: 'mantra_id = ?', whereArgs: [id]);
    await db.delete('japa_sessions', where: 'mantra_id = ?', whereArgs: [id]);
    await db.delete('mantras', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateMantra(int id, String name) async {
    final db = await instance;
    await db.update('mantras', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateMantraFull(Mantra mantra) async {
    final db = await instance;
    await db.update('mantras', mantra.toMap(), where: 'id = ?', whereArgs: [mantra.id]);
  }

  // ── Japa Sessions ──

  static Future<void> insertSession(JapaSession session) async {
    final db = await instance;
    await db.insert('japa_sessions', session.toMap());
  }

  static Future<int> getTodayCount(int mantraId) async {
    final db = await instance;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(count), 0) as total FROM japa_sessions WHERE mantra_id = ? AND started_at >= ?',
      [mantraId, startOfDay],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  static Future<int> getTotalCount(int mantraId) async {
    final db = await instance;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(count), 0) as total FROM japa_sessions WHERE mantra_id = ?',
      [mantraId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  static Future<int> getCountSinceDate(int mantraId, DateTime since) async {
    final db = await instance;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(count), 0) as total FROM japa_sessions WHERE mantra_id = ? AND started_at >= ?',
      [mantraId, since.toIso8601String()],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  static Future<void> resetAll() async {
    final db = await instance;
    await db.delete('sankalps');
    await db.delete('japa_sessions');
    await db.delete('mantras');
  }

  static Future<Map<String, dynamic>?> getLastSession(int mantraId) async {
    final db = await instance;
    final rows = await db.query(
      'japa_sessions',
      where: 'mantra_id = ?',
      whereArgs: [mantraId],
      orderBy: 'ended_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<List<JapaSession>> getAllSessions({int? mantraId}) async {
    final db = await instance;
    final rows = await db.query(
      'japa_sessions',
      where: mantraId != null ? 'mantra_id = ?' : null,
      whereArgs: mantraId != null ? [mantraId] : null,
      orderBy: 'started_at DESC',
    );
    return rows.map(JapaSession.fromMap).toList();
  }

  /// Returns daily counts for the last [days] days for a mantra, ordered oldest->newest.
  static Future<List<DailyCount>> getDailyCounts(int mantraId, int days) async {
    final db = await instance;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final rows = await db.rawQuery(
      "SELECT DATE(started_at) as day, SUM(count) as total "
      "FROM japa_sessions WHERE mantra_id = ? AND started_at >= ? "
      "GROUP BY DATE(started_at) ORDER BY day ASC",
      [mantraId, start.toIso8601String()],
    );

    final map = <String, int>{};
    for (final row in rows) {
      map[row['day'] as String] = (row['total'] as int?) ?? 0;
    }

    return List.generate(days, (i) {
      final d = start.add(Duration(days: i));
      final key = d.toIso8601String().substring(0, 10);
      return DailyCount(date: d, count: map[key] ?? 0);
    });
  }

  /// Returns the number of consecutive days (ending today) with at least one session.
  static Future<int> getCurrentStreak(int mantraId) async {
    final db = await instance;
    final rows = await db.rawQuery(
      "SELECT DISTINCT DATE(started_at) as day "
      "FROM japa_sessions WHERE mantra_id = ? "
      "ORDER BY day DESC",
      [mantraId],
    );

    if (rows.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime.parse(rows.first['day'] as String);

    // Allow streak to start from today or yesterday
    var expected = (firstDay == today) ? today : today.subtract(const Duration(days: 1));
    if (firstDay != today && firstDay != today.subtract(const Duration(days: 1))) {
      return 0;
    }

    for (final row in rows) {
      final day = DateTime.parse(row['day'] as String);
      if (day == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (day.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }

  // ── Sankalps ──

  static Future<Sankalp> insertSankalp(Sankalp sankalp) async {
    final db = await instance;
    final id = await db.insert('sankalps', sankalp.toMap());
    return Sankalp.fromMap({...sankalp.toMap(), 'id': id});
  }

  static Future<Sankalp?> getActiveSankalp(int mantraId) async {
    final db = await instance;
    final rows = await db.query(
      'sankalps',
      where: 'mantra_id = ? AND completed_at IS NULL',
      whereArgs: [mantraId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sankalp.fromMap(rows.first);
  }

  static Future<void> completeSankalp(int id) async {
    final db = await instance;
    await db.update(
      'sankalps',
      {'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> getCountForDate(int mantraId, DateTime date) async {
    final db = await instance;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(count), 0) as total FROM japa_sessions WHERE mantra_id = ? AND started_at >= ? AND started_at <= ? ',
      [mantraId, startOfDay, endOfDay],
    );
    return (result.first['total'] as int) ?? 0;
  }

  static Future<List<Sankalp>> getCompletedSankalps(int mantraId) async {
    final db = await instance;
    final rows = await db.query(
      'sankalps',
      where: 'mantra_id = ? AND completed_at IS NOT NULL',
      whereArgs: [mantraId],
      orderBy: 'completed_at DESC',
    );
    return rows.map(Sankalp.fromMap).toList();
  }
}

class DailyCount {
  final DateTime date;
  final int count;
  const DailyCount({required this.date, required this.count});
}

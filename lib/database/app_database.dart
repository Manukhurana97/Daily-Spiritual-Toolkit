import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/mantra.dart';
import '../models/japa_session.dart';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mantras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
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
      },
    );
  }

  // ── Mantras ──

  static Future<List<Mantra>> getMantras() async {
    final db = await instance;
    final rows = await db.query('mantras', orderBy: 'created_at ASC');
    return rows.map(Mantra.fromMap).toList();
  }

  static Future<Mantra> insertMantra(String name) async {
    final db = await instance;
    final mantra = Mantra(name: name, createdAt: DateTime.now());
    final id = await db.insert('mantras', mantra.toMap());
    return mantra.copyWith(id: id);
  }

  static Future<void> deleteMantra(int id) async {
    final db = await instance;
    await db.delete('japa_sessions', where: 'mantra_id = ?', whereArgs: [id]);
    await db.delete('mantras', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateMantra(int id, String name) async {
    final db = await instance;
    await db.update('mantras', {'name': name}, where: 'id = ?', whereArgs: [id]);
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

  static Future<void> resetAll() async {
    final db = await instance;
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
}

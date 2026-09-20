import 'package:drift/drift.dart';
// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

void main() {
  test('POLISH §8 — EXPLAIN QUERY PLAN on stats queries', () async {
    final db = AppDatabase(NativeDatabase.memory());


    final queries = [
      (
        'Q1: focus_sessions date range',
        'SELECT id, local_date, started_at, ended_at, actual_duration_s, outcome, '
            'interruptions_internal, interruptions_external, focus_rating, '
            'project_id, tz_offset_min '
            'FROM focus_sessions WHERE local_date >= ? AND local_date <= ?;',
        [const Variable<String>('2024-01-01'), const Variable<String>('2026-09-14')],
      ),
      (
        'Q2: DISTINCT events date range',
        'SELECT DISTINCT local_date FROM events '
            'WHERE local_date >= ? AND local_date <= ?;',
        [const Variable<String>('2024-01-01'), const Variable<String>('2026-09-14')],
      ),
      (
        'Q3: focus_sessions daily totals by outcome and range',
        'SELECT local_date, SUM(actual_duration_s) AS total_seconds '
            'FROM focus_sessions '
            'WHERE outcome = ? AND local_date >= ? AND local_date <= ? '
            'GROUP BY local_date;',
        [
          const Variable<String>('completed'),
          const Variable<String>('2024-01-01'),
          const Variable<String>('2026-09-14'),
        ],
      ),
      (
        'Q4: focus_sessions count by outcome',
        'SELECT COUNT(*) AS session_count FROM focus_sessions WHERE outcome = ?;',
        [const Variable<String>('completed')],
      ),
    ];

    print('\n==================== POLISH §8 EXPLAIN QUERY PLAN ====================');
    for (final q in queries) {
      print('\n[${q.$1}]');
      print('SQL: ${q.$2}');
      final rows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${q.$2}',
        variables: q.$3,
      ).get();

      for (final row in rows) {
        print('  PLAN: ${row.data['detail']}');
      }
    }
    print('======================================================================\n');

    await db.close();
  });
}

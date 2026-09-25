import 'package:drift/drift.dart';
// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

void main() {
  test('POLISH §8 — EXPLAIN QUERY PLAN on stats queries', () async {
    final db = AppDatabase(NativeDatabase.memory());

    // NOTE: SQLite's query planner can choose a full scan over an index on a
    // very small/empty table even when the index exists. We seed realistic row
    // counts (hundreds of rows) before asserting plan output so the planner
    // consistently favors index lookups. Do not remove this seed data.
    await db.transaction(() async {
      for (var i = 0; i < 200; i++) {
        final month = (i % 12 + 1).toString().padLeft(2, '0');
        final day = (i % 28 + 1).toString().padLeft(2, '0');
        final date = '2025-$month-$day';
        final outcome = i % 2 == 0 ? 'completed' : 'abandoned';

        await db.customInsert(
          'INSERT INTO focus_sessions (id, mode, started_at, ended_at, local_date, tz_offset_min, outcome, updated_at, device_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<String>('session-$i'),
            const Variable<String>('pomodoro'),
            Variable<int>(1700000000000 + i * 10000),
            Variable<int>(1700000000000 + i * 10000 + 1500000),
            Variable<String>(date),
            const Variable<int>(0),
            Variable<String>(outcome),
            Variable<int>(1700000000000 + i * 10000),
            const Variable<String>('device-test'),
          ],
        );

        await db.customInsert(
          'INSERT INTO events (id, type, occurred_at, recorded_at, local_date, tz_id, tz_offset_min, payload, device_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<String>('event-$i'),
            const Variable<String>('task_created'),
            Variable<int>(1700000000000 + i * 10000),
            Variable<int>(1700000000000 + i * 10000),
            Variable<String>(date),
            const Variable<String>('UTC'),
            const Variable<int>(0),
            const Variable<String>('{}'),
            const Variable<String>('device-test'),
          ],
        );
      }
    });

    final queries = [
      (
        name: 'Q1: focus_sessions date range',
        sql: 'SELECT id, local_date, started_at, ended_at, actual_duration_s, outcome, '
            'interruptions_internal, interruptions_external, focus_rating, '
            'project_id, tz_offset_min '
            'FROM focus_sessions WHERE local_date >= ? AND local_date <= ?;',
        variables: [const Variable<String>('2024-01-01'), const Variable<String>('2026-09-14')],
        targetTable: 'focus_sessions',
        expectedIndex: 'focus_sessions_local_date_idx',
      ),
      (
        name: 'Q2: DISTINCT events date range',
        sql: 'SELECT DISTINCT local_date FROM events '
            'WHERE local_date >= ? AND local_date <= ?;',
        variables: [const Variable<String>('2024-01-01'), const Variable<String>('2026-09-14')],
        targetTable: 'events',
        expectedIndex: 'events_local_date_idx',
      ),
      (
        name: 'Q3: focus_sessions daily totals by outcome and range',
        sql: 'SELECT local_date, SUM(actual_duration_s) AS total_seconds '
            'FROM focus_sessions '
            'WHERE outcome = ? AND local_date >= ? AND local_date <= ? '
            'GROUP BY local_date;',
        variables: [
          const Variable<String>('completed'),
          const Variable<String>('2024-01-01'),
          const Variable<String>('2026-09-14'),
        ],
        targetTable: 'focus_sessions',
        expectedIndex: 'focus_sessions_outcome_idx',
      ),
      (
        name: 'Q4: focus_sessions count by outcome',
        sql: 'SELECT COUNT(*) AS session_count FROM focus_sessions WHERE outcome = ?;',
        variables: [const Variable<String>('completed')],
        targetTable: 'focus_sessions',
        expectedIndex: 'focus_sessions_outcome_idx',
      ),
    ];

    print('\n==================== POLISH §8 EXPLAIN QUERY PLAN ====================');
    for (final q in queries) {
      print('\n[${q.name}]');
      print('SQL: ${q.sql}');
      final rows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${q.sql}',
        variables: q.variables,
      ).get();

      final details = <String>[];
      for (final row in rows) {
        final detail = row.data['detail'] as String;
        details.add(detail);
        print('  PLAN: $detail');
      }

      // Assert that SQLite uses the expected index (either USING INDEX or USING COVERING INDEX)
      final usesExpectedIndex = details.any(
        (d) =>
            d.contains('USING INDEX ${q.expectedIndex}') ||
            d.contains('USING COVERING INDEX ${q.expectedIndex}'),
      );
      expect(
        usesExpectedIndex,
        isTrue,
        reason: '${q.name}: Query plan should use index ${q.expectedIndex}. Plan details: $details',
      );

      // Explicitly assert it does NOT contain an unqualified SCAN on the target indexed table
      final hasUnqualifiedScan = details.any(
        (d) =>
            d.contains('SCAN ${q.targetTable}') &&
            !d.contains('USING INDEX') &&
            !d.contains('USING COVERING INDEX'),
      );
      expect(
        hasUnqualifiedScan,
        isFalse,
        reason: '${q.name}: Query plan must not perform an unqualified SCAN on ${q.targetTable}. Plan details: $details',
      );
    }
    print('======================================================================\n');

    await db.close();
  });
}


import 'dart:io';
import 'dart:ui';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  final db = ref.watch(databaseProvider);
  return DataExportService(db: db);
});

/// Service responsible for generating and sharing plaintext CSV exports of habits and focus sessions.
class DataExportService {
  final AppDatabase db;

  DataExportService({required this.db});

  /// Helper to properly escape CSV fields.
  String _escapeCsv(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Exports all habits and their logged entries as a CSV string.
  Future<String> generateHabitsCsv() async {
    final habits = await (db.select(db.habits)..orderBy([(h) => OrderingTerm.asc(h.title)])).get();
    final entries = await (db.select(db.habitEntries)..orderBy([(e) => OrderingTerm.desc(e.localDate)])).get();

    final habitMap = {for (var h in habits) h.id: h};

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Habit Title,Status,Schedule,Target Count,Unit,Date,Check Count,Completed,Skipped,Note,Last Checked At');

    for (final entry in entries) {
      final habit = habitMap[entry.habitId];
      final title = habit?.title ?? 'Unknown Habit';
      final status = habit?.status ?? '';
      final schedule = habit?.scheduleRule ?? '';
      final target = habit?.targetCount ?? 1;
      final unit = habit?.unitLabel ?? '';
      final isCompleted = entry.checkCount >= target;
      final lastChecked = entry.lastCheckedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(entry.lastCheckedAt!, isUtc: true).toIso8601String()
          : '';

      buffer.writeln([
        _escapeCsv(title),
        _escapeCsv(status),
        _escapeCsv(schedule),
        _escapeCsv(target),
        _escapeCsv(unit),
        _escapeCsv(entry.localDate),
        _escapeCsv(entry.checkCount),
        _escapeCsv(isCompleted ? 'YES' : 'NO'),
        _escapeCsv(entry.skipped ? 'YES' : 'NO'),
        _escapeCsv(entry.note ?? ''),
        _escapeCsv(lastChecked),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Exports all focus sessions as a CSV string.
  Future<String> generateFocusSessionsCsv() async {
    final sessions = await (db.select(db.focusSessions)..orderBy([(s) => OrderingTerm.desc(s.startedAt)])).get();

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Date,Mode,Planned Minutes,Actual Minutes,Started At,Ended At,Task ID,Project ID');

    for (final s in sessions) {
      final startedIso = DateTime.fromMillisecondsSinceEpoch(s.startedAt, isUtc: true).toIso8601String();
      final endedIso = DateTime.fromMillisecondsSinceEpoch(s.endedAt, isUtc: true).toIso8601String();
      final plannedMin = (s.plannedDurationS / 60).round();
      final actualMin = (s.actualDurationS / 60).round();

      buffer.writeln([
        _escapeCsv(s.localDate),
        _escapeCsv(s.mode),
        _escapeCsv(plannedMin),
        _escapeCsv(actualMin),
        _escapeCsv(startedIso),
        _escapeCsv(endedIso),
        _escapeCsv(s.taskId ?? ''),
        _escapeCsv(s.projectId ?? ''),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Writes [csvContent] to a temp file and opens the system share sheet.
  Future<void> shareCsv({
    required String csvContent,
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(csvContent, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, name: fileName, mimeType: 'text/csv')],
        subject: 'Cairn Data Export: $fileName',
        text: 'Exported from Cairn ($fileName)',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

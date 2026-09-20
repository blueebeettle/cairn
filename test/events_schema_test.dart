import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/event_types.dart';
import 'package:habit_tracker/data/database/app_database.dart';

void main() {
  group('Events Schema & Invariants - SPEC.md §2', () {
    test('Session event types defined per §2.2', () {
      expect(EventTypes.sessionStarted, equals('session_started'));
      expect(EventTypes.sessionCompleted, equals('session_completed'));
      expect(EventTypes.sessionAbandoned, equals('session_abandoned'));
      expect(EventTypes.sessionInterrupted, equals('session_interrupted'));
      expect(EventTypes.breakStarted, equals('break_started'));
      expect(EventTypes.breakCompleted, equals('break_completed'));
    });

    test('Task event types defined per §2.2', () {
      expect(EventTypes.taskCreated, equals('task_created'));
      expect(EventTypes.taskCompleted, equals('task_completed'));
      expect(EventTypes.taskUncompleted, equals('task_uncompleted'));
      expect(EventTypes.taskRescheduled, equals('task_rescheduled'));
      expect(EventTypes.taskArchived, equals('task_archived'));
    });

    test('Habit event types reserved per §2.2', () {
      expect(EventTypes.habitChecked, equals('habit_checked'));
      expect(EventTypes.habitSkipped, equals('habit_skipped'));
      expect(EventTypes.habitUnchecked, equals('habit_unchecked'));
      expect(EventTypes.habitFreezeUsed, equals('habit_freeze_used'));
    });

    test('Event data class serialization adheres to schema §2.1', () {
      final payloadMap = {
        'mode': 'pomodoro',
        'planned_duration_s': 1500,
        'task_id': '018f1000-0000-7000-0000-000000000042',
      };

      const event = Event(
        id: '018f1000-0000-7000-0000-000000000001',
        type: EventTypes.sessionStarted,
        occurredAt: 1725883200000,
        recordedAt: 1725883200100,
        localDate: '2026-09-09',
        tzId: 'America/Edmonton',
        tzOffsetMin: -360,
        subjectType: SubjectTypes.session,
        subjectId: '018f1000-0000-7000-0000-000000000002',
        payload: '{"mode":"pomodoro","planned_duration_s":1500,"task_id":"018f1000-0000-7000-0000-000000000042"}',
        deviceId: 'device-test-123',
      );
      expect(jsonDecode(event.payload), equals(payloadMap));

      final json = event.toJson();
      expect(json['id'], equals('018f1000-0000-7000-0000-000000000001'));
      expect(json['type'], equals(EventTypes.sessionStarted));
      expect(json['occurred_at'], equals(1725883200000));
      expect(json['recorded_at'], equals(1725883200100));
      expect(json['local_date'], equals('2026-09-09'));
      expect(json['tz_id'], equals('America/Edmonton'));
      expect(json['tz_offset_min'], equals(-360));
      expect(json['subject_type'], equals(SubjectTypes.session));
      expect(json['subject_id'], equals('018f1000-0000-7000-0000-000000000002'));
      expect(json['device_id'], equals('device-test-123'));

      final decodedPayload = jsonDecode(json['payload'] as String);
      expect(decodedPayload['mode'], equals('pomodoro'));
      expect(decodedPayload['planned_duration_s'], equals(1500));
      expect(decodedPayload['task_id'], equals('018f1000-0000-7000-0000-000000000042'));
    });
  });
}

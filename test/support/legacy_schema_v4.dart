/// The exact schema-4 database found on a real device (DDL only, no data): the
/// install was fresh, yet its `focus_stack.sqlite` was an old file, most likely
/// put back by Android Auto Backup from an earlier install.
///
/// Schema 4 predates `habits`, `habit_entries`, `task_reminder_offsets` and
/// `habit_reminder_times`, and its `tasks` table still carries the three
/// single-reminder columns schema 6 replaced. The schema was already 6 at the
/// first commit, so no tagged release wrote this shape, but a restored backup can
/// bring one back and the current code has to open it. When it cannot, the
/// exception leaves `main()` before `runApp` and the launch screen stays up with
/// nothing shown.
const legacySchemaV4Version = 4;

/// Tables first, then indexes, in the order they were created.
const legacySchemaV4Statements = <String>[
  r'''CREATE TABLE "events" ("id" TEXT NOT NULL, "type" TEXT NOT NULL, "occurred_at" INTEGER NOT NULL, "recorded_at" INTEGER NOT NULL, "local_date" TEXT NOT NULL, "tz_id" TEXT NOT NULL, "tz_offset_min" INTEGER NOT NULL, "subject_type" TEXT NULL, "subject_id" TEXT NULL, "payload" TEXT NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"))''',
  r'''CREATE TABLE "focus_sessions" ("id" TEXT NOT NULL, "task_id" TEXT NULL, "project_id" TEXT NULL, "mode" TEXT NOT NULL, "planned_duration_s" INTEGER NOT NULL DEFAULT 0, "actual_duration_s" INTEGER NOT NULL DEFAULT 0, "started_at" INTEGER NOT NULL, "ended_at" INTEGER NOT NULL, "local_date" TEXT NOT NULL, "tz_offset_min" INTEGER NOT NULL, "tz_id" TEXT NOT NULL DEFAULT '', "outcome" TEXT NOT NULL, "interruptions_internal" INTEGER NOT NULL DEFAULT 0, "interruptions_external" INTEGER NOT NULL DEFAULT 0, "focus_rating" INTEGER NULL, "note" TEXT NULL, "is_manual" INTEGER NOT NULL DEFAULT 0 CHECK ("is_manual" IN (0, 1)), "updated_at" INTEGER NOT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"))''',
  r'''CREATE TABLE "projects" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "color_index" INTEGER NOT NULL DEFAULT 0, "archived" INTEGER NOT NULL DEFAULT 0 CHECK ("archived" IN (0, 1)), "updated_at" INTEGER NOT NULL, "device_id" TEXT NOT NULL, "deleted_at" INTEGER NULL, PRIMARY KEY ("id"))''',
  r'''CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))''',
  r'''CREATE TABLE "tags" ("id" TEXT NOT NULL, "name" TEXT NOT NULL UNIQUE, "updated_at" INTEGER NOT NULL, "device_id" TEXT NOT NULL, "deleted_at" INTEGER NULL, PRIMARY KEY ("id"))''',
  r'''CREATE TABLE "task_tags" ("task_id" TEXT NOT NULL, "tag_id" TEXT NOT NULL, PRIMARY KEY ("task_id", "tag_id"))''',
  r'''CREATE TABLE "tasks" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "notes" TEXT NULL, "project_id" TEXT NULL, "parent_id" TEXT NULL, "priority" INTEGER NOT NULL DEFAULT 4, "due_at" INTEGER NULL, "due_is_all_day" INTEGER NOT NULL DEFAULT 0 CHECK ("due_is_all_day" IN (0, 1)), "estimate_pomodoros" INTEGER NULL, "status" TEXT NOT NULL DEFAULT 'open', "created_at" INTEGER NOT NULL, "created_local_date" TEXT NOT NULL, "completed_at" INTEGER NULL, "completed_local_date" TEXT NULL, "reschedule_count" INTEGER NOT NULL DEFAULT 0, "recurrence_rule" TEXT NULL, "recurrence_mode" TEXT NULL, "recurrence_parent_id" TEXT NULL, "sort_order" REAL NOT NULL DEFAULT 0.0, "reminder_notification_id" INTEGER NULL, "reminder_offset_min" INTEGER NULL, "reminder_enabled" INTEGER NULL CHECK ("reminder_enabled" IN (0, 1)), "updated_at" INTEGER NOT NULL, "device_id" TEXT NOT NULL, "deleted_at" INTEGER NULL, PRIMARY KEY ("id"))''',
  r'''CREATE TABLE "timer_states" ("id" INTEGER NOT NULL DEFAULT 1, "session_id" TEXT NULL, "started_at_utc" INTEGER NULL, "planned_duration_s" INTEGER NOT NULL DEFAULT 0, "mode" TEXT NOT NULL DEFAULT 'pomodoro', "paused_accumulated_s" INTEGER NOT NULL DEFAULT 0, "paused_at_utc" INTEGER NULL, "task_id" TEXT NULL, "project_id" TEXT NULL, PRIMARY KEY ("id"))''',
  r'''CREATE INDEX events_local_date_idx ON events (local_date)''',
  r'''CREATE INDEX events_subject_idx ON events (subject_type, subject_id)''',
  r'''CREATE INDEX events_type_local_date_idx ON events (type, local_date)''',
  r'''CREATE INDEX focus_sessions_local_date_idx ON focus_sessions (local_date)''',
  r'''CREATE INDEX focus_sessions_outcome_idx ON focus_sessions (outcome)''',
  r'''CREATE INDEX focus_sessions_task_id_idx ON focus_sessions (task_id)''',
  r'''CREATE INDEX tasks_completed_local_date_idx ON tasks (completed_local_date)''',
  r'''CREATE INDEX tasks_due_at_idx ON tasks (due_at)''',
  r'''CREATE INDEX tasks_parent_id_idx ON tasks (parent_id)''',
  r'''CREATE INDEX tasks_status_idx ON tasks (status)''',
];

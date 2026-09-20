import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/database_provider.dart';
import '../../../theme/app_theme.dart';
import '../../backup/domain/backup_providers.dart';


/// Developer screen displaying the raw immutable LOGICAL DAY EVENT STREAM per SPEC.md §0 and §2.1,
/// plus POLISH §8 test data generation, database wipe, and query plan explanation.
class DeveloperEventsScreen extends ConsumerStatefulWidget {
  const DeveloperEventsScreen({super.key});

  @override
  ConsumerState<DeveloperEventsScreen> createState() =>
      _DeveloperEventsScreenState();
}

class _DeveloperEventsScreenState extends ConsumerState<DeveloperEventsScreen> {
  bool _isGenerating = false;
  bool _isWiping = false;
  double _progress = 0.0;
  String? _explainOutput;

  bool get _isBusy => _isGenerating || _isWiping;

  Future<void> _handleGenerate() async {
    if (_isBusy) return;

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    try {
      final seeder = ref.read(seedDataProvider);
      final report = await seeder.generate(
        onProgress: (fraction) {
          if (mounted) {
            setState(() => _progress = fraction);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Seeded in ${report.elapsedMs}ms (${(report.elapsedMs / 1000).toStringAsFixed(2)}s):\n$report',
            ),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seeding failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      debugPrint('Seeding failed: $e\n$st');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _progress = 0.0;
        });
      }
    }
  }

  Future<void> _handleWipe() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This will permanently wipe all events, focus sessions, tasks, projects, '
          'tags, and timer state. Settings (device_id, theme, day start) are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isWiping = true);

    try {
      final seeder = ref.read(seedDataProvider);
      await seeder.wipe();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data deleted successfully. Database wiped clean.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wipe failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      debugPrint('Wipe failed: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _isWiping = false);
      }
    }
  }

  Future<void> _handleExplainQueryPlans() async {
    final db = ref.read(databaseProvider);

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

    final buffer = StringBuffer();

    for (final q in queries) {
      buffer.writeln('=== ${q.$1} ===');
      buffer.writeln(q.$2.trim());
      buffer.writeln('--- EXPLAIN QUERY PLAN ---');
      try {
        final rows = await db.customSelect(
          'EXPLAIN QUERY PLAN ${q.$2}',
          variables: q.$3,
        ).get();
        for (final row in rows) {
          final detail = row.data['detail'];
          buffer.writeln('  • $detail');
        }
      } catch (e) {
        buffer.writeln('  ERROR: $e');
      }
      buffer.writeln();
    }

    final output = buffer.toString();
    debugPrint(output);

    if (mounted) {
      setState(() {
        _explainOutput = output;
      });
    }
  }

  Future<void> _showSupabaseConfigDialog(BuildContext context) async {
    final state = ref.read(backupControllerProvider);
    final savedKey = await ref.read(supabaseBackupServiceProvider).getSupabaseAnonKey();
    if (!context.mounted) return;
    final urlController = TextEditingController(text: state.supabaseUrl ?? '');
    final keyController = TextEditingController(text: savedKey ?? '');
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configure Supabase Project'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Developer settings: Enter your Project URL and Anon Key from your Supabase Dashboard:',
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Project URL (https://xyz.supabase.co)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Anon Public API Key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final url = urlController.text.trim();
                    final key = keyController.text.trim();
                    if (url.isEmpty || key.isEmpty) {
                      setDialogState(() => error = 'Both URL and Anon Key are required.');
                      return;
                    }
                    if (!url.startsWith('http://') && !url.startsWith('https://')) {
                      setDialogState(() => error = 'URL must start with https://');
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    await ref.read(backupControllerProvider.notifier).configureSupabase(
                          url: url,
                          anonKey: key,
                        );
                  },
                  child: const Text('Save Credentials'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final timeService = ref.watch(timeServiceProvider);
    final todayLocalDate = timeService.todayLocalDate();
    final selectedDate = ref.watch(selectedDateProvider);
    final currentViewDate = selectedDate ?? todayLocalDate;
    final isToday = currentViewDate == todayLocalDate;

    final eventsAsync = isToday
        ? ref.watch(todayEventsStreamProvider)
        : ref.watch(eventsForDateStreamProvider(currentViewDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer & Performance'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── POLISH §8 Performance Controls ──────────────────────────────
            Card(
              color: colors.surfaceContainerLow,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'POLISH §8 — TEST DATA & PERFORMANCE',
                      style: textTheme.labelSmall?.copyWith(
                        color: tokens.textSecondary,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isGenerating) ...[
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text(
                        'Generating 2 years of history (~12,000 rows)... ${(_progress * 100).toStringAsFixed(0)}%',
                        style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ] else if (_isWiping) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        'Wiping database...',
                        style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text('Generate 2 Years Data'),
                            onPressed: _isBusy ? null : _handleGenerate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Delete All Data'),
                            onPressed: _isBusy ? null : _handleWipe,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.analytics_outlined, size: 18),
                            label: const Text('Run EXPLAIN QUERY PLAN (4 queries)'),
                            onPressed: _isBusy ? null : _handleExplainQueryPlans,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                            label: const Text('Configure Supabase Project'),
                            onPressed: () => _showSupabaseConfigDialog(context),
                          ),
                        ),
                      ],
                    ),
                    if (_explainOutput != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _explainOutput!,
                          style: textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Event Stream ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOGICAL DAY EVENT STREAM',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'local_date: $currentViewDate',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return Card(
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No events recorded for $currentViewDate.\nEvery user action writes an immutable event to the log.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final event in events)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            event.type,
                            style: textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            '${event.localDate} • ${event.tzId}\nPayload: ${event.payload}',
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                          trailing: Text(
                            '#${event.id.length > 8 ? event.id.substring(0, 8) : event.id}',
                            style: textTheme.labelSmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading events: $err',
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../domain/backup_providers.dart';
import '../domain/backup_service.dart';
import '../domain/data_export_service.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.tokens;
    final textTheme = theme.textTheme;

    // Show SnackBars for success or error
    ref.listen<BackupState>(backupControllerProvider, (prev, next) {
      if (next.lastErrorMessage != null &&
          next.lastErrorMessage != prev?.lastErrorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.lastErrorMessage!),
            backgroundColor: tokens.danger,
          ),
        );
      }
      if (next.lastSuccessMessage != null &&
          next.lastSuccessMessage != prev?.lastSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.lastSuccessMessage!),
            backgroundColor: colorScheme.primary,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Header Card ───────────────────────────────────────────────────
          Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: tokens.lineSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Only you can open your backups',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your data is encrypted on your phone with your backup password before leaving this device. Nobody — not even cloud providers or us — can read your notes or focus sessions.',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (state.lastBackupDate != null)
                          Text(
                            'Last backup: ${_formatDate(state.lastBackupDate!)}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            'You have no backups yet. Backing up protects your habit streaks, focus sessions, and task history if you lose or replace your phone.',
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Primary Option: Offline Encrypted Vault Backup (.cairn) ────────
          Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Encrypted Backup File (.cairn)',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Recommended • Offline',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zero-knowledge, 100% offline AES-256-GCM encrypted file. Your habits and tasks are encrypted on this device before anything touches storage. Move it to a new phone, store on a USB drive, or share to your personal cloud.',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: state.isExporting
                            ? null
                            : () => _showExportDialog(context),
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: Text(
                          state.isExporting ? 'Encrypting...' : 'Save a backup file',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.isImporting || state.isRestoring
                            ? null
                            : () => _pickAndRestoreFile(context),
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Restore from backup file'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Secondary Option: Cairn Cloud Account (Supabase) ────────────────
          Card(
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: tokens.lineSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_outlined, color: tokens.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cairn Cloud Account',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                      if (state.isCloudAccountLoggedIn)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Connected',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.isCloudAccountLoggedIn
                        ? 'Signed in as ${state.cloudAccountEmail}. Your encrypted vault can be synchronized and restored across devices without manually transferring files.'
                        : 'Sign in with an email and password to sync your encrypted vault across devices.',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!state.isCloudAccountLoggedIn)
                    FilledButton.tonalIcon(
                      onPressed: () => _showCloudAccountDialog(context),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Sign In or Register'),
                    )
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: state.isCloudSyncing
                              ? null
                              : () => _showCloudBackupDialog(context),
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: Text(
                            state.isCloudSyncing ? 'Syncing...' : 'Back up to my account',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.isCloudSyncing
                              ? null
                              : () => _showCloudRestoreDialog(context),
                          icon: const Icon(Icons.cloud_download_outlined, size: 18),
                          label: const Text('Restore from my account'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(backupControllerProvider.notifier)
                          .signOutSupabase(),
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Sign Out'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Tertiary Option: Plaintext Data Export (CSV) ────────────────────
          Card(
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: tokens.lineSoft),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_chart_outlined, color: tokens.textSecondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Plaintext Data Export (CSV)',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export readable spreadsheet files (.csv) of your habit logs and focus sessions for use in Excel, Google Sheets, or Obsidian.',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportHabitsCsv(context),
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: const Text('Export Habits (CSV)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _exportFocusSessionsCsv(context),
                        icon: const Icon(Icons.timer_outlined, size: 18),
                        label: const Text('Export Focus Sessions (CSV)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ── A.1 Reusable No-Recovery Warning Box ────────────────────────────────────
  Widget _buildNoRecoveryWarning(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: tokens.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'There is no way to recover this password.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tokens.warning,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your backup is encrypted on your phone before it is uploaded. Nobody — not even us — can read it or reset the password. If you forget it, the backup cannot be opened. Write it down somewhere safe.',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ── A.6 Restore Confirmation Dialog (Replace everything?) ───────────────────
  Future<bool> _showConfirmReplaceDialog(BuildContext context, {required String backupDateStr}) async {
    final controller = ref.read(backupControllerProvider.notifier);
    final counts = await controller.getCurrentDataCounts();
    if (!context.mounted) return false;
    final tokens = context.tokens;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Replace everything on this phone?'),
          content: Text(
            'This deletes the ${counts.sessionCount} sessions, ${counts.taskCount} tasks and ${counts.habitCount} habits currently on this phone and replaces them with the backup from $backupDateStr.\n\nThis cannot be undone.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace everything'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _showExportDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set Backup Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNoRecoveryWarning(context),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Backup password',
                        helperText: 'At least 8 characters. This is the only thing protecting your backup.',
                        helperMaxLines: 2,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Toggle password visibility',
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm backup password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: TextStyle(color: context.tokens.danger, fontSize: 12),
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
                    final pass = passwordController.text.trim();
                    final conf = confirmController.text.trim();

                    if (pass.length < 8) {
                      setDialogState(() => error = 'Password must be at least 8 characters.');
                      return;
                    }
                    if (pass != conf) {
                      setDialogState(() => error = 'Passwords do not match.');
                      return;
                    }

                    Navigator.of(dialogContext).pop();

                    final box = context.findRenderObject() as RenderBox?;
                    final origin = box != null
                        ? (box.localToGlobal(Offset.zero) & box.size)
                        : null;

                    await ref
                        .read(backupControllerProvider.notifier)
                        .exportLocalBackup(
                          password: pass,
                          sharePositionOrigin: origin,
                        );
                  },
                  child: const Text('Encrypt & Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndRestoreFile(BuildContext context) async {
    final controller = ref.read(backupControllerProvider.notifier);
    final file = await controller.pickFileForRestore();
    if (file == null || !mounted) return;

    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    BackupManifest? manifest;
    bool isVerifying = false;

    if (!mounted || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Restore from Backup File'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected file: ${file.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (manifest == null) ...[
                      const Text(
                        'Enter your backup password to verify and inspect its contents:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Backup password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscure = !obscure),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Password Verified!',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('• Exported: ${_formatFriendlyDate(manifest!.exportedAt)}'),
                            Text('• Tasks: ${manifest!.taskCount}'),
                            Text('• Focus Sessions: ${manifest!.sessionCount}'),
                            Text('• Projects: ${manifest!.projectCount}'),
                            Text('• Events logged: ${manifest!.eventCount}'),
                          ],
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(color: context.tokens.danger, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    controller.cancelPendingRestore();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                if (manifest == null)
                  FilledButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final pass = passwordController.text.trim();
                            if (pass.isEmpty) {
                              setDialogState(() => error = 'Please enter the password.');
                              return;
                            }
                            setDialogState(() {
                              isVerifying = true;
                              error = null;
                            });

                            final result = await controller.inspectPendingFile(pass);
                            if (result != null) {
                              setDialogState(() {
                                manifest = result;
                                isVerifying = false;
                              });
                            } else {
                              setDialogState(() {
                                isVerifying = false;
                                error = 'Decryption failed: Incorrect password or invalid file.';
                              });
                            }
                          },
                    child: Text(isVerifying ? 'Verifying...' : 'Verify Password'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.tokens.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await _showConfirmReplaceDialog(
                        context,
                        backupDateStr: _formatFriendlyDate(manifest!.exportedAt),
                      );
                      if (confirmed && dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        await controller.restorePendingFile(passwordController.text.trim());
                      }
                    },
                    child: const Text('Replace Everything & Restore'),
                  ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _showCloudAccountDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;
    bool isLoading = false;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isSignUp ? 'Create Cairn Account' : 'Sign In to Cairn Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignUp
                          ? 'Create an account to back up and sync your habits across devices.'
                          : 'Sign in to access your cloud backup and sync across devices.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(color: context.tokens.danger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setDialogState(() {
                        isSignUp = !isSignUp;
                        error = null;
                      }),
                      child: Text(
                        isSignUp
                            ? 'Already have an account? Sign In'
                            : 'Don\'t have an account? Sign Up',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final pass = passwordController.text.trim();
                          if (email.isEmpty || pass.isEmpty) {
                            setDialogState(() => error = 'Email and password are required.');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            error = null;
                          });

                          final controller = ref.read(backupControllerProvider.notifier);
                          final success = isSignUp
                              ? await controller.signUpSupabase(email: email, password: pass)
                              : await controller.signInSupabase(email: email, password: pass);

                          if (success && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          } else {
                            setDialogState(() {
                              isLoading = false;
                              error = ref.read(backupControllerProvider).lastErrorMessage ??
                                  'Authentication failed.';
                            });
                          }
                        },
                  child: Text(isLoading
                      ? 'Please wait...'
                      : (isSignUp ? 'Create Account' : 'Sign In')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCloudBackupDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Back up to my account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNoRecoveryWarning(context),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Backup password',
                        helperText: 'At least 8 characters. This is the only thing protecting your backup.',
                        helperMaxLines: 2,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Toggle password visibility',
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm backup password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: TextStyle(color: context.tokens.danger, fontSize: 12),
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
                    final pass = passwordController.text.trim();
                    final conf = confirmController.text.trim();
                    if (pass.length < 8) {
                      setDialogState(() => error = 'Password must be at least 8 characters.');
                      return;
                    }
                    if (pass != conf) {
                      setDialogState(() => error = 'Passwords do not match.');
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    await ref.read(backupControllerProvider.notifier).backupToCloud(password: pass);
                  },
                  child: const Text('Encrypt & Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCloudRestoreDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Restore from my account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your backup password to download and decrypt your latest account backup:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Backup password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Toggle password visibility',
                          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(color: context.tokens.danger, fontSize: 12),
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
                    final pass = passwordController.text.trim();
                    if (pass.isEmpty) {
                      setDialogState(() => error = 'Please enter your password.');
                      return;
                    }

                    final confirmed = await _showConfirmReplaceDialog(
                      context,
                      backupDateStr: 'Cairn account',
                    );
                    if (confirmed && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      await ref.read(backupControllerProvider.notifier).restoreFromCloud(password: pass);
                    }
                  },
                  child: const Text('Download & Restore'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final month = months[dt.month - 1];
      final day = dt.day;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$month $day, ${dt.year} at $hour:$min';
    } catch (_) {
      return isoString;
    }
  }

  String _formatFriendlyDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      final month = months[dt.month - 1];
      return '${dt.day} $month ${dt.year}';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _exportHabitsCsv(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
    try {
      final exportService = ref.read(dataExportServiceProvider);
      final csv = await exportService.generateHabitsCsv();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      await exportService.shareCsv(
        csvContent: csv,
        fileName: 'cairn-habits-$dateStr.csv',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export habits: $e')),
        );
      }
    }
  }

  Future<void> _exportFocusSessionsCsv(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
    try {
      final exportService = ref.read(dataExportServiceProvider);
      final csv = await exportService.generateFocusSessionsCsv();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      await exportService.shareCsv(
        csvContent: csv,
        fileName: 'cairn-sessions-$dateStr.csv',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export sessions: $e')),
        );
      }
    }
  }
}

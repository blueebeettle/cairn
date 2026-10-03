import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

/// Shown instead of the app when startup throws before the first frame.
///
/// Stands alone on purpose: no Riverpod, no database, and not [AppTheme],
/// whose fonts come from the network. Those are what may just have failed.
/// There is no destructive recovery option here, deliberately.
class StartupErrorScreen extends StatelessWidget {
  /// Keyed by [attempt] so a failed retry replaces the screen rather than
  /// updating it; "Trying again…" must not outlive the attempt it belongs to.
  StartupErrorScreen({
    required this.error,
    required this.stackTrace,
    required this.attempt,
    required this.onRetry,
  }) : super(key: ValueKey(attempt));

  final Object error;
  final StackTrace stackTrace;

  /// 1 for the first failure, one more for each failed retry.
  final int attempt;

  /// Re-runs startup. Completes once the retry has either replaced this screen
  /// with the app or with a new error screen.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cairn',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: _StartupErrorBody(
        error: error,
        stackTrace: stackTrace,
        attempt: attempt,
        onRetry: onRetry,
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  final light = brightness == Brightness.light;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: BrandColors.purple,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: light ? BrandColors.cream : BrandColors.darkGround,
  );
}

class _StartupErrorBody extends StatefulWidget {
  const _StartupErrorBody({
    required this.error,
    required this.stackTrace,
    required this.attempt,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stackTrace;
  final int attempt;
  final Future<void> Function() onRetry;

  @override
  State<_StartupErrorBody> createState() => _StartupErrorBodyState();
}

class _StartupErrorBodyState extends State<_StartupErrorBody> {
  bool _retrying = false;
  bool _showDetails = false;

  String get _details {
    final trace = widget.stackTrace.toString().trim();
    return trace.isEmpty ? '${widget.error}' : '${widget.error}\n\n$trace';
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _copyDetails() async {
    await Clipboard.setData(ClipboardData(text: _details));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Details copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.primary),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      "Cairn couldn't open its data",
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This is usually recoverable, so try again. If it keeps '
                    'happening, tap Show details and include what you see '
                    'when you report it.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (widget.attempt > 1) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Still couldn't open it (attempt ${widget.attempt}).",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _retrying ? null : _retry,
                    child: Text(_retrying ? 'Trying again…' : 'Try again'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _showDetails = !_showDetails),
                      child: Text(_showDetails ? 'Hide details' : 'Show details'),
                    ),
                  ),
                  if (_showDetails) ...[
                    // Above the trace, which can run to hundreds of lines.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _copyDetails,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy details'),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _details,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

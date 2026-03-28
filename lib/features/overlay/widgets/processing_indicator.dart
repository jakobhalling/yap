import 'dart:async';

import 'package:flutter/material.dart';

import 'package:yap/shared/theme/app_theme.dart';

/// Shows the LLM processing header with streaming output text.
///
/// While [isComplete] is false a loading spinner is displayed next to the
/// profile name. Once complete the spinner disappears.
class ProcessingIndicator extends StatefulWidget {
  final String profileName;
  final String streamingText;
  final bool isComplete;

  const ProcessingIndicator({
    super.key,
    required this.profileName,
    required this.streamingText,
    required this.isComplete,
  });

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator> {
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.isComplete) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });
    }
  }

  @override
  void didUpdateWidget(ProcessingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isComplete && !oldWidget.isComplete) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _statusText {
    if (widget.isComplete) return 'Done';
    if (widget.streamingText.isEmpty) {
      if (_elapsedSeconds < 3) return 'Connecting to Claude...';
      if (_elapsedSeconds < 8) return 'Waiting for response... (${_elapsedSeconds}s)';
      return 'Still waiting... (${_elapsedSeconds}s) — check API key if this persists';
    }
    final chars = widget.streamingText.length;
    return 'Streaming... ($chars chars, ${_elapsedSeconds}s)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!widget.isComplete) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (widget.isComplete) ...[
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              'Processing with: ${widget.profileName}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _statusText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.streamingText.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                widget.streamingText,
                style: AppTheme.transcriptStyle.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

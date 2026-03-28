import 'package:flutter/material.dart';

import 'package:yap/shared/theme/app_theme.dart';

/// Shows the LLM processing header with streaming output text.
///
/// While [isComplete] is false a loading spinner is displayed next to the
/// profile name. Once complete the spinner disappears.
class ProcessingIndicator extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!isComplete) ...[
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
            if (isComplete) ...[
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              isComplete
                  ? 'Processed with: $profileName'
                  : 'Processing with: $profileName',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (streamingText.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: SelectableText(
                streamingText,
                style: AppTheme.transcriptStyle.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          )
        else if (!isComplete)
          Text(
            'Waiting for response...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yap/services/database/database.dart';

/// Full detail view for a single history entry.
///
/// Shows raw transcript, profile info, processed text, and the final pasted
/// text. Each section has a "Copy to clipboard" button.
class HistoryDetailView extends StatelessWidget {
  final HistoryData entry;
  final VoidCallback onBack;

  const HistoryDetailView({
    super.key,
    required this.entry,
    required this.onBack,
  });

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '$hour:$minute $amPm';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return 'Unknown';
    final d = Duration(seconds: seconds.round());
    return '${d.inMinutes}:${(d.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text('Entry detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Meta info
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(_formatTimestamp(entry.createdAt), style: theme.textTheme.bodyMedium),
              const SizedBox(width: 16),
              Icon(Icons.timer, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(_formatDuration(entry.durationSeconds), style: theme.textTheme.bodyMedium),
            ],
          ),
          if (entry.profileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Profile: ${entry.profileName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // Profile prompt (collapsible)
          if (entry.profilePrompt != null && entry.profilePrompt!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CollapsibleSection(
              title: 'System prompt used',
              content: entry.profilePrompt!,
              onCopy: () => _copy(context, entry.profilePrompt!),
            ),
          ],

          // Raw transcript
          const SizedBox(height: 16),
          _textSection(
            context,
            title: 'Raw transcript',
            text: entry.rawTranscript,
          ),

          // Processed text
          if (entry.processedText != null && entry.processedText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _textSection(
              context,
              title: 'Processed text',
              text: entry.processedText!,
            ),
          ],

          // Final pasted text
          const SizedBox(height: 16),
          _textSection(
            context,
            title: 'Pasted text',
            text: entry.pastedText,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _textSection(
    BuildContext context, {
    required String title,
    required String text,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy to clipboard',
              onPressed: () => _copy(context, text),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlight
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: highlight
                ? Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  )
                : null,
          ),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// A section whose content can be expanded/collapsed.
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback onCopy;

  const _CollapsibleSection({
    required this.title,
    required this.content,
    required this.onCopy,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                widget.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_expanded)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy',
                  onPressed: widget.onCopy,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              widget.content,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

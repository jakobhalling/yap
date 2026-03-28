import 'package:flutter/material.dart';

import 'package:yap/shared/theme/app_theme.dart';

/// Scrollable text view for the transcript.
///
/// When [isStreaming] is true the view auto-scrolls to the bottom as new text
/// arrives. Once streaming is done, the user can scroll freely.
class TranscriptView extends StatefulWidget {
  final String text;
  final bool isStreaming;

  const TranscriptView({
    super.key,
    required this.text,
    this.isStreaming = false,
  });

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && widget.text != oldWidget.text) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return Text(
        'Listening...',
        style: AppTheme.transcriptStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: SelectableText(
            widget.text,
            style: AppTheme.transcriptStyle.copyWith(
              color: widget.isStreaming
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

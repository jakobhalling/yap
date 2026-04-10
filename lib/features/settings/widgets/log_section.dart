import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/services/log_service.dart';

/// Live event log viewer. Shows structured events newest-first with
/// category icons, color-coded severity, and auto-refresh.
class LogSection extends ConsumerStatefulWidget {
  const LogSection({super.key});

  @override
  ConsumerState<LogSection> createState() => _LogSectionState();
}

class _LogSectionState extends ConsumerState<LogSection> {
  final _scrollController = ScrollController();
  List<LogEvent> _events = [];
  StreamSubscription<LogEvent>? _sub;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _events = Log.events;
    _sub = Log.stream.listen((_) {
      if (!mounted) return;
      setState(() {
        _events = Log.events;
      });
      if (_autoScroll && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Text('Event Log', style: theme.textTheme.headlineSmall),
              const Spacer(),
              Tooltip(
                message: _autoScroll
                    ? 'Auto-scroll on (newest visible)'
                    : 'Auto-scroll off',
                child: IconButton(
                  icon: Icon(
                    _autoScroll
                        ? Icons.vertical_align_top
                        : Icons.vertical_align_top_outlined,
                    size: 20,
                    color: _autoScroll
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Clear log',
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    Log.clearEvents();
                    setState(() => _events = []);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${_events.length} events',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Event list
        Expanded(
          child: _events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No events yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Events will appear here as you use the app',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) =>
                      _EventTile(event: _events[index]),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual event tile
// ---------------------------------------------------------------------------

class _EventTile extends StatelessWidget {
  final LogEvent event;
  const _EventTile({required this.event});

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isError = event.level == 'ERROR';
    final isWarn = event.level == 'WARN';

    final levelColor = isError
        ? colorScheme.error
        : isWarn
            ? Colors.amber.shade700
            : colorScheme.onSurfaceVariant;

    final levelBg = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.3)
        : isWarn
            ? Colors.amber.withValues(alpha: 0.08)
            : Colors.transparent;

    final icon = _iconForTag(event.tag);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: levelBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: levelColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.tag,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: levelColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(event.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isError
                          ? colorScheme.error
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForTag(String tag) {
    switch (tag) {
      case 'Audio':
        return Icons.mic_outlined;
      case 'Hotkey':
        return Icons.keyboard_outlined;
      case 'Recording':
        return Icons.fiber_manual_record_outlined;
      case 'AssemblyAI':
        return Icons.subtitles_outlined;
      case 'Processing':
      case 'Claude':
        return Icons.psychology_outlined;
      case 'Paste':
        return Icons.content_paste_outlined;
      case 'Overlay':
        return Icons.layers_outlined;
      case 'Update':
        return Icons.system_update_outlined;
      case 'Tray':
        return Icons.dock_outlined;
      case 'Startup':
        return Icons.power_settings_new_outlined;
      default:
        return Icons.apps_outlined;
    }
  }
}

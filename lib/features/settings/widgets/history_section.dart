import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/history/history_providers.dart';
import 'package:yap/features/settings/settings_providers.dart';

/// History settings: enable/disable recording, clear all, storage path.
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({super.key});

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  bool _historyEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = ref.read(settingsServiceProvider);
      final enabled = await settings.getHistoryEnabled();
      if (mounted) {
        setState(() {
          _historyEnabled = enabled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setHistoryEnabled(bool value) async {
    setState(() => _historyEnabled = value);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setHistoryEnabled(value);
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This will permanently delete all saved transcriptions and processed text. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final history = ref.read(historyServiceProvider);
        await history.clearAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('History cleared')),
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('History', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Record history'),
          subtitle: const Text(
            'Save transcriptions and processed text for later reference',
          ),
          value: _historyEnabled,
          onChanged: _setHistoryEnabled,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Clear all history'),
          subtitle: const Text('Permanently delete all saved entries'),
          onTap: _clearHistory,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Storage location'),
          subtitle: const Text('Database stored in app data directory'),
          enabled: false,
        ),
      ],
    );
  }
}

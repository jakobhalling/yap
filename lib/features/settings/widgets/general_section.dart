import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/settings/settings_providers.dart';

/// General settings: double-tap speed, model selection, sound cues, auto-start.
class GeneralSection extends ConsumerStatefulWidget {
  const GeneralSection({super.key});

  @override
  ConsumerState<GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends ConsumerState<GeneralSection> {
  double _doubleTapMs = 400;
  String _model = 'sonnet';
  bool _soundCues = true;
  bool _autoStart = false;
  bool _loading = true;

  static const _models = {
    'haiku': 'Claude Haiku',
    'sonnet': 'Claude Sonnet',
    'opus': 'Claude Opus',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = ref.read(settingsServiceProvider);
      final tap = await settings.getDoubleTapThreshold();
      final model = await settings.getClaudeModel();
      final sound = await settings.getSoundCuesEnabled();
      final auto = await settings.getAutoStartOnBoot();
      if (mounted) {
        setState(() {
          _doubleTapMs = tap.toDouble();
          _model = model;
          _soundCues = sound;
          _autoStart = auto;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setDoubleTap(double value) async {
    setState(() => _doubleTapMs = value);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setDoubleTapThreshold(value.round());
    } catch (_) {}
  }

  Future<void> _setModel(String? value) async {
    if (value == null) return;
    setState(() => _model = value);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setClaudeModel(value);
    } catch (_) {}
  }

  Future<void> _setSoundCues(bool value) async {
    setState(() => _soundCues = value);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setSoundCuesEnabled(value);
    } catch (_) {}
  }

  Future<void> _setAutoStart(bool value) async {
    setState(() => _autoStart = value);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setAutoStartOnBoot(value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('General', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),

        // Double-tap speed
        Text(
          'Double-tap speed: ${_doubleTapMs.round()} ms',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'How fast you need to double-tap the trigger key.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          value: _doubleTapMs,
          min: 200,
          max: 600,
          divisions: 8,
          label: '${_doubleTapMs.round()} ms',
          onChanged: _setDoubleTap,
        ),
        const SizedBox(height: 24),

        // Claude model
        Text(
          'Claude model',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _model,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _models.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: _setModel,
        ),
        const SizedBox(height: 24),

        // Sound cues
        SwitchListTile(
          title: const Text('Sound cues'),
          subtitle: const Text('Play sounds on record start/stop'),
          value: _soundCues,
          onChanged: _setSoundCues,
        ),
        const SizedBox(height: 8),

        // Auto-start
        SwitchListTile(
          title: const Text('Start on boot'),
          subtitle: const Text('Launch Yap automatically when you log in'),
          value: _autoStart,
          onChanged: _setAutoStart,
        ),
      ],
    );
  }
}

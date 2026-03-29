import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/settings/settings_providers.dart';
import 'package:yap/features/settings/widgets/hotkey_recorder.dart';
import 'package:yap/services/audio/audio_service.dart';
import 'package:yap/services/providers.dart';

/// General settings: microphone, double-tap speed, model selection, sound cues, auto-start.
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
  String _triggerKey = Platform.isMacOS ? 'left_command' : 'left_alt';

  // Microphone
  List<AudioDevice> _devices = [];
  String? _selectedDeviceId;
  bool _loadingDevices = true;

  static const _models = {
    'haiku': 'Claude Haiku',
    'sonnet': 'Claude Sonnet',
    'opus': 'Claude Opus',
  };

  @override
  void initState() {
    super.initState();
    _load();
    _loadDevices();
  }

  Future<void> _load() async {
    try {
      final settings = ref.read(settingsServiceProvider);
      final tap = await settings.getDoubleTapThreshold();
      final model = await settings.getClaudeModel();
      final sound = await settings.getSoundCuesEnabled();
      final auto = await settings.getAutoStartOnBoot();
      final trigger = await settings.getTriggerKey();
      if (mounted) {
        setState(() {
          _doubleTapMs = tap.toDouble();
          _model = model;
          _soundCues = sound;
          _autoStart = auto;
          _triggerKey = trigger;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDevices() async {
    try {
      final audio = ref.read(audioServiceProvider);
      final devices = await audio.listDevices();
      final settings = ref.read(settingsServiceProvider);
      final savedId = await settings.getMicrophoneDeviceId();
      if (mounted) {
        setState(() {
          _devices = devices;
          _selectedDeviceId = savedId;
          _loadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _setDevice(String? deviceId) async {
    setState(() => _selectedDeviceId = deviceId);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setMicrophoneDeviceId(deviceId);
    } catch (_) {}
  }

  Future<void> _setTriggerKey(String key) async {
    setState(() => _triggerKey = key);
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setTriggerKey(key);
      final hotkeyService = ref.read(hotkeyServiceProvider);
      await hotkeyService.setTriggerKey(key);
    } catch (_) {}
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

        // Microphone selection
        Text(
          'Microphone',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_loadingDevices)
          const LinearProgressIndicator()
        else if (_devices.isEmpty)
          Text(
            'No microphones found',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                ),
          )
        else
          DropdownButtonFormField<String?>(
            value: _devices.any((d) => d.id == _selectedDeviceId)
                ? _selectedDeviceId
                : null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'System default${_devices.any((d) => d.isDefault) ? ' (${_devices.firstWhere((d) => d.isDefault).name})' : ''}',
                ),
              ),
              ..._devices.map((d) => DropdownMenuItem<String?>(
                    value: d.id,
                    child: Text(
                      d.name + (d.isDefault ? ' (default)' : ''),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: _setDevice,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh devices'),
              onPressed: () {
                setState(() => _loadingDevices = true);
                _loadDevices();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Trigger key
        Text(
          'Trigger shortcut',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Double-tap this key to start/stop recording.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        HotkeyRecorder(
          currentKey: _triggerKey,
          onKeyChanged: _setTriggerKey,
        ),
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

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/settings/settings_providers.dart';
import 'package:yap/features/settings/widgets/hotkey_recorder.dart';
import 'package:yap/services/audio/audio_service.dart';
import 'package:yap/services/providers.dart';
import 'package:yap/services/update_service.dart';
import 'package:yap/utils/constants.dart';

import 'dart:async';

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

  // Update state
  UpdateState _updateState = const UpdateState();
  StreamSubscription<UpdateState>? _updateSub;

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
    _initUpdateListener();
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    super.dispose();
  }

  void _initUpdateListener() {
    final updateService = ref.read(updateServiceProvider);
    _updateState = updateService.state;
    _updateSub = updateService.stateStream.listen((state) {
      if (mounted) setState(() => _updateState = state);
    });
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

  Future<void> _checkForUpdate() async {
    final updateService = ref.read(updateServiceProvider);
    await updateService.checkForUpdate(appVersion);
  }

  Future<void> _downloadUpdate() async {
    final updateService = ref.read(updateServiceProvider);
    await updateService.downloadUpdate();
  }

  Future<void> _installUpdate() async {
    final updateService = ref.read(updateServiceProvider);
    await updateService.installAndRestart();
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
        const SizedBox(height: 24),

        // Updates
        Text('Updates', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildUpdateCard(context),
      ],
    );
  }

  Widget _buildUpdateCard(BuildContext context) {
    final status = _updateState.status;
    final isActionable = status == UpdateStatus.updateAvailable ||
        status == UpdateStatus.readyToInstall;
    final isError = status == UpdateStatus.error;
    final isDownloading = status == UpdateStatus.downloading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActionable
              ? Colors.orange.withOpacity(0.5)
              : isError
                  ? Colors.red.withOpacity(0.5)
                  : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _updateIcon,
                size: 18,
                color: _updateIconColor,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_updateLabel)),
              _buildUpdateAction(),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: Text(
              'Current version: v$appVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (isDownloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _updateState.downloadProgress > 0
                  ? _updateState.downloadProgress
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              '${(_updateState.downloadProgress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (isError && _updateState.error != null) ...[
            const SizedBox(height: 4),
            Text(
              _updateState.error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  IconData get _updateIcon {
    switch (_updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.upToDate:
        return Icons.check_circle_outline;
      case UpdateStatus.checking:
        return Icons.sync;
      case UpdateStatus.updateAvailable:
        return Icons.system_update;
      case UpdateStatus.downloading:
        return Icons.downloading;
      case UpdateStatus.readyToInstall:
        return Icons.install_desktop;
      case UpdateStatus.installing:
        return Icons.install_desktop;
      case UpdateStatus.error:
        return Icons.error_outline;
    }
  }

  Color? get _updateIconColor {
    switch (_updateState.status) {
      case UpdateStatus.updateAvailable:
      case UpdateStatus.downloading:
        return Colors.orange;
      case UpdateStatus.readyToInstall:
        return Colors.green;
      case UpdateStatus.error:
        return Colors.red;
      default:
        return null;
    }
  }

  String get _updateLabel {
    switch (_updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.upToDate:
        return 'You are up to date';
      case UpdateStatus.checking:
        return 'Checking for updates...';
      case UpdateStatus.updateAvailable:
        return 'Version ${_updateState.availableVersion} is available';
      case UpdateStatus.downloading:
        return 'Downloading update...';
      case UpdateStatus.readyToInstall:
        return 'Version ${_updateState.availableVersion} ready to install';
      case UpdateStatus.installing:
        return 'Installing...';
      case UpdateStatus.error:
        return 'Update failed';
    }
  }

  Widget _buildUpdateAction() {
    switch (_updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.upToDate:
      case UpdateStatus.error:
        return TextButton(
          onPressed: _checkForUpdate,
          child: const Text('Check'),
        );
      case UpdateStatus.checking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UpdateStatus.updateAvailable:
        return TextButton(
          onPressed: _downloadUpdate,
          child: const Text('Download'),
        );
      case UpdateStatus.downloading:
        return const SizedBox.shrink();
      case UpdateStatus.readyToInstall:
        return FilledButton(
          onPressed: _installUpdate,
          child: const Text('Install & Restart'),
        );
      case UpdateStatus.installing:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }
}

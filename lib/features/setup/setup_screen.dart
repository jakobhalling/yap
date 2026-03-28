import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/processing/processing_providers.dart';
import 'package:yap/features/settings/settings_providers.dart';

/// First-boot setup wizard. Walks the user through:
/// 1. Welcome
/// 2. AssemblyAI API key
/// 3. Anthropic API key
/// 4. Hotkey explanation
/// 5. Done — minimize to tray
class SetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const SetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;

  final _assemblyController = TextEditingController();
  final _anthropicController = TextEditingController();
  bool _assemblyObscured = true;
  bool _anthropicObscured = true;
  bool _anthropicTesting = false;
  bool? _anthropicValid;
  String? _anthropicError;

  static const _totalSteps = 4;

  @override
  void dispose() {
    _assemblyController.dispose();
    _anthropicController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return true; // Welcome
      case 1:
        return _assemblyController.text.trim().isNotEmpty;
      case 2:
        return _anthropicController.text.trim().isNotEmpty;
      case 3:
        return true; // Hotkey info
      default:
        return true;
    }
  }

  Future<void> _next() async {
    if (_step == 1) {
      // Save AssemblyAI key
      final settings = ref.read(settingsServiceProvider);
      await settings.setAssemblyAIApiKey(_assemblyController.text.trim());
    } else if (_step == 2) {
      // Save Anthropic key
      final settings = ref.read(settingsServiceProvider);
      await settings.setAnthropicApiKey(_anthropicController.text.trim());
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      // Mark setup complete
      final settings = ref.read(settingsServiceProvider);
      await settings.setSetupComplete(true);
      widget.onComplete();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _testAnthropicKey() async {
    setState(() {
      _anthropicTesting = true;
      _anthropicValid = null;
      _anthropicError = null;
    });
    try {
      final claude = ref.read(claudeServiceProvider);
      final valid =
          await claude.validateApiKey(_anthropicController.text.trim());
      setState(() {
        _anthropicValid = valid;
        _anthropicError = valid ? null : 'Invalid API key';
        _anthropicTesting = false;
      });
    } catch (e) {
      setState(() {
        _anthropicValid = false;
        _anthropicError = e.toString();
        _anthropicTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress
              Row(
                children: List.generate(_totalSteps, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 40),

              // Content
              Expanded(child: _buildStep(context)),

              // Navigation
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canAdvance ? _next : null,
                    child: Text(_step == _totalSteps - 1 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _welcomeStep(context);
      case 1:
        return _assemblyKeyStep(context);
      case 2:
        return _anthropicKeyStep(context);
      case 3:
        return _hotkeyStep(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _welcomeStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mic, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Welcome to Yap',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Voice-driven text input for any application.\n\n'
          'Speak freely — Yap transcribes and structures your speech '
          'into clean text while preserving all the detail and context you provide.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          "Let's set up your API keys to get started.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _assemblyKeyStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AssemblyAI API Key',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Yap uses AssemblyAI for real-time speech transcription. '
          'Get your API key at assemblyai.com',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _assemblyController,
          obscureText: _assemblyObscured,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'API Key',
            hintText: 'Paste your AssemblyAI API key',
            suffixIcon: IconButton(
              icon: Icon(
                _assemblyObscured ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _assemblyObscured = !_assemblyObscured),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your key is stored locally and only sent to AssemblyAI.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _anthropicKeyStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Anthropic API Key',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Yap uses Claude to process your transcripts into structured, '
          'well-organized text. Get your key at console.anthropic.com',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _anthropicController,
                obscureText: _anthropicObscured,
                onChanged: (_) => setState(() {
                  _anthropicValid = null;
                  _anthropicError = null;
                }),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'API Key',
                  hintText: 'Paste your Anthropic API key',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _anthropicObscured
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                            () => _anthropicObscured = !_anthropicObscured),
                      ),
                      if (_anthropicValid == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                      if (_anthropicValid == false)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.cancel, color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _anthropicController.text.trim().isNotEmpty &&
                      !_anthropicTesting
                  ? _testAnthropicKey
                  : null,
              child: _anthropicTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test'),
            ),
          ],
        ),
        if (_anthropicError != null) ...[
          const SizedBox(height: 8),
          Text(
            _anthropicError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Your key is stored locally and only sent to Anthropic.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _hotkeyStep(BuildContext context) {
    final theme = Theme.of(context);
    final triggerKey = Platform.isMacOS ? 'Left Command' : 'Left Alt';
    final pasteKey = Platform.isMacOS ? 'Cmd+V' : 'Ctrl+V';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.keyboard, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'How to use Yap',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _hotkeyRow(
          context,
          icon: Icons.touch_app,
          title: 'Double-tap $triggerKey',
          subtitle: 'Start recording — speak freely',
        ),
        const SizedBox(height: 16),
        _hotkeyRow(
          context,
          icon: Icons.stop_circle_outlined,
          title: 'Double-tap $triggerKey again',
          subtitle: 'Stop recording — see your transcript',
        ),
        const SizedBox(height: 16),
        _hotkeyRow(
          context,
          icon: Icons.auto_awesome,
          title: 'Press 1-4 to process',
          subtitle: 'Pick a prompt profile to structure your text',
        ),
        const SizedBox(height: 16),
        _hotkeyRow(
          context,
          icon: Icons.keyboard_return,
          title: 'Press Enter to paste',
          subtitle: 'Result is pasted into your focused app ($pasteKey)',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Yap lives in your system tray. Right-click the tray icon for settings.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hotkeyRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 28, color: theme.colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

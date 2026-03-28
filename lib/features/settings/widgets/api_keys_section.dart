import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/settings/settings_providers.dart';
import 'package:yap/features/processing/processing_providers.dart';

/// API key inputs for AssemblyAI and Anthropic with validation buttons.
class ApiKeysSection extends ConsumerStatefulWidget {
  const ApiKeysSection({super.key});

  @override
  ConsumerState<ApiKeysSection> createState() => _ApiKeysSectionState();
}

class _ApiKeysSectionState extends ConsumerState<ApiKeysSection> {
  final _assemblyController = TextEditingController();
  final _anthropicController = TextEditingController();
  bool _assemblyObscured = true;
  bool _anthropicObscured = true;

  // Validation state: null = not tested, true = ok, false = failed
  bool? _assemblyValid;
  bool? _anthropicValid;
  String? _assemblyError;
  String? _anthropicError;
  bool _assemblyTesting = false;
  bool _anthropicTesting = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final settings = ref.read(settingsServiceProvider);
      final assemblyKey = await settings.getAssemblyAIApiKey();
      final anthropicKey = await settings.getAnthropicApiKey();
      if (mounted) {
        setState(() {
          _assemblyController.text = assemblyKey ?? '';
          _anthropicController.text = anthropicKey ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAssemblyKey(String value) async {
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setAssemblyAIApiKey(value);
      setState(() {
        _assemblyValid = null;
        _assemblyError = null;
      });
    } catch (_) {}
  }

  Future<void> _saveAnthropicKey(String value) async {
    try {
      final settings = ref.read(settingsServiceProvider);
      await settings.setAnthropicApiKey(value);

      setState(() {
        _anthropicValid = null;
        _anthropicError = null;
      });
    } catch (_) {}
  }

  Future<void> _testAssemblyKey() async {
    setState(() {
      _assemblyTesting = true;
      _assemblyValid = null;
      _assemblyError = null;
    });
    try {
      // Basic validation: key must be non-empty
      final key = _assemblyController.text.trim();
      if (key.isEmpty) {
        setState(() {
          _assemblyValid = false;
          _assemblyError = 'API key is empty';
          _assemblyTesting = false;
        });
        return;
      }
      // Full validation would call the AssemblyAI API. For now, accept if
      // the key looks plausible (non-empty).
      setState(() {
        _assemblyValid = true;
        _assemblyTesting = false;
      });
    } catch (e) {
      setState(() {
        _assemblyValid = false;
        _assemblyError = e.toString();
        _assemblyTesting = false;
      });
    }
  }

  Future<void> _testAnthropicKey() async {
    setState(() {
      _anthropicTesting = true;
      _anthropicValid = null;
      _anthropicError = null;
    });
    try {
      final claude = ref.read(claudeServiceProvider);
      final valid = await claude.validateApiKey(_anthropicController.text.trim());
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
  void dispose() {
    _assemblyController.dispose();
    _anthropicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('API Keys', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Your API keys are stored locally and never sent anywhere except the respective services.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _apiKeyField(
          label: 'AssemblyAI API Key',
          controller: _assemblyController,
          obscured: _assemblyObscured,
          onToggleObscure: () =>
              setState(() => _assemblyObscured = !_assemblyObscured),
          onChanged: _saveAssemblyKey,
          onTest: _testAssemblyKey,
          isTesting: _assemblyTesting,
          isValid: _assemblyValid,
          errorText: _assemblyError,
        ),
        const SizedBox(height: 24),
        _apiKeyField(
          label: 'Anthropic API Key',
          controller: _anthropicController,
          obscured: _anthropicObscured,
          onToggleObscure: () =>
              setState(() => _anthropicObscured = !_anthropicObscured),
          onChanged: _saveAnthropicKey,
          onTest: _testAnthropicKey,
          isTesting: _anthropicTesting,
          isValid: _anthropicValid,
          errorText: _anthropicError,
        ),
      ],
    );
  }

  Widget _apiKeyField({
    required String label,
    required TextEditingController controller,
    required bool obscured,
    required VoidCallback onToggleObscure,
    required ValueChanged<String> onChanged,
    required VoidCallback onTest,
    required bool isTesting,
    required bool? isValid,
    required String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscured,
                onChanged: onChanged,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Enter API key',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          obscured ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: onToggleObscure,
                        tooltip: obscured ? 'Show' : 'Hide',
                      ),
                      if (isValid == true)
                        const Icon(Icons.check_circle, color: Colors.green),
                      if (isValid == false)
                        const Icon(Icons.cancel, color: Colors.red),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isTesting ? null : onTest,
              child: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test'),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }
}

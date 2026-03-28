import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yap/features/processing/processing_providers.dart';
import 'package:yap/shared/prompts/default_prompts.dart';

/// Editor for the 4 prompt profile slots.
///
/// Each profile has a name and a system prompt text area. Slots 1-3 have a
/// "Reset to default" button; slot 4 is user-defined.
class ProfilesSection extends ConsumerStatefulWidget {
  const ProfilesSection({super.key});

  @override
  ConsumerState<ProfilesSection> createState() => _ProfilesSectionState();
}

class _ProfilesSectionState extends ConsumerState<ProfilesSection> {
  List<_ProfileEditState> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final dao = ref.read(promptProfileDaoProvider);
      final profiles = await dao.getAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles
              .map((p) => _ProfileEditState(
                    slot: p.slot,
                    nameController: TextEditingController(text: p.name),
                    promptController:
                        TextEditingController(text: p.systemPrompt),
                  ))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      // Fall back to defaults if DAO is not available yet.
      if (mounted) {
        setState(() {
          _profiles = DefaultPrompts.defaults
              .map((d) => _ProfileEditState(
                    slot: d.slot,
                    nameController: TextEditingController(text: d.name),
                    promptController:
                        TextEditingController(text: d.systemPrompt),
                  ))
              .toList();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile(int slot) async {
    final profile = _profiles.firstWhere((p) => p.slot == slot);
    try {
      final dao = ref.read(promptProfileDaoProvider);
      await dao.updateProfile(
        slot,
        name: profile.nameController.text,
        systemPrompt: profile.promptController.text,
      );
    } catch (_) {
      // DAO may not be wired yet — ignore during parallel development.
    }
  }

  Future<void> _resetProfile(int slot) async {
    final defaultProfile =
        DefaultPrompts.defaults.firstWhere((d) => d.slot == slot);
    final profile = _profiles.firstWhere((p) => p.slot == slot);
    setState(() {
      profile.nameController.text = defaultProfile.name;
      profile.promptController.text = defaultProfile.systemPrompt;
    });
    await _saveProfile(slot);
  }

  @override
  void dispose() {
    for (final p in _profiles) {
      p.nameController.dispose();
      p.promptController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _profiles.length,
      separatorBuilder: (_, __) => const Divider(height: 32),
      itemBuilder: (context, index) {
        final p = _profiles[index];
        return _profileEditor(context, p);
      },
    );
  }

  Widget _profileEditor(BuildContext context, _ProfileEditState p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Profile ${p.slot}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (p.slot <= 3)
              TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset to default'),
                onPressed: () => _resetProfile(p.slot),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: p.nameController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Name',
            hintText: 'e.g. Structured prompt',
          ),
          onChanged: (_) => _saveProfile(p.slot),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: p.promptController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'System prompt',
            hintText: 'Enter the system prompt for this profile...',
            alignLabelWithHint: true,
          ),
          maxLines: 6,
          minLines: 3,
          onChanged: (_) => _saveProfile(p.slot),
        ),
        const SizedBox(height: 8),
        // Preview chip
        Text(
          'Overlay preview:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${p.slot} . ${p.nameController.text.isEmpty ? "(empty)" : p.nameController.text}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ProfileEditState {
  final int slot;
  final TextEditingController nameController;
  final TextEditingController promptController;

  _ProfileEditState({
    required this.slot,
    required this.nameController,
    required this.promptController,
  });
}

import 'package:flutter/material.dart';

import 'package:yap/features/overlay/overlay_controller.dart';

/// Horizontal bar showing profile shortcuts and Enter/Esc hints.
///
/// Displayed at the bottom of the overlay when the transcript is complete.
class ProfileSelector extends StatelessWidget {
  final List<ProfileOption> profiles;
  final int? selectedSlot;

  const ProfileSelector({
    super.key,
    required this.profiles,
    this.selectedSlot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.45);
    final activeColor = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _KeyLabel(
              keyText: 'Enter',
              label: 'Paste raw',
              color: activeColor,
              isSelected: false,
            ),
            _separator(context),
            for (final profile in profiles) ...[
              _KeyLabel(
                keyText: '${profile.slot}',
                label: profile.isEmpty ? '(empty)' : profile.name,
                color: profile.isEmpty ? mutedColor : activeColor,
                isSelected: selectedSlot == profile.slot,
              ),
              if (profile.slot < 4) const SizedBox(width: 12),
            ],
            _separator(context),
            _KeyLabel(
              keyText: 'Esc',
              label: 'Cancel',
              color: activeColor,
              isSelected: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '|',
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _KeyLabel extends StatelessWidget {
  final String keyText;
  final String label;
  final Color color;
  final bool isSelected;

  const _KeyLabel({
    required this.keyText,
    required this.label,
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : color.withOpacity(0.4),
            ),
            borderRadius: BorderRadius.circular(3),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : null,
          ),
          child: Text(
            keyText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}

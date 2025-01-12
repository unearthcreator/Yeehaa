import 'package:flutter/material.dart';

/// A reusable row widget for displaying a label alongside a toggle switch.
class ToggleRow extends StatelessWidget {
  /// The label to describe the toggle.
  final String label;

  /// The current value of the toggle.
  final bool value;

  /// A callback for when the toggle value changes.
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The label for the toggle
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 8), // Add space between label and toggle
        // The toggle switch
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
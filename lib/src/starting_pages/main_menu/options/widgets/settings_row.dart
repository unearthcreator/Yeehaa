import 'package:flutter/material.dart';

class SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;

  const SettingsRow({required this.label, required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }
}
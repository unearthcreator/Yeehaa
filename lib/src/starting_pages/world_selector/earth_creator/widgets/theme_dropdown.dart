import 'package:flutter/material.dart';

class ThemeDropdown extends StatelessWidget {
  final String selectedTheme;
  final ValueChanged<String?> onChanged; // Accepts nullable String

  const ThemeDropdown({
    required this.selectedTheme,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedTheme,
      items: const [
        DropdownMenuItem(value: 'Dawn', child: Text('Dawn')),
        DropdownMenuItem(value: 'Day', child: Text('Day')),
        DropdownMenuItem(value: 'Dusk', child: Text('Dusk')),
        DropdownMenuItem(value: 'Night', child: Text('Night')),
      ],
      onChanged: onChanged, // Updated to handle nullable callback
    );
  }
}
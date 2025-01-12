import 'package:flutter/material.dart';

Future<String?> showIconSelectionDialog(BuildContext context) async {
  // The icons you have: cross.png, cinema.png, cricket.png
  final icons = [
    "cross",
    "cinema",
    "cricket",
  ];

  return showDialog<String>(
    context: context,
    builder: (iconDialogContext) {
      return AlertDialog(
        title: const Text('Select an Icon'),
        content: SizedBox(
          width: MediaQuery.of(iconDialogContext).size.width * 0.5,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: icons.map((iconName) {
              return GestureDetector(
                onTap: () {
                  // When tapped, return this icon name
                  Navigator.of(iconDialogContext).pop(iconName);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/$iconName.png',
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(iconName, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}
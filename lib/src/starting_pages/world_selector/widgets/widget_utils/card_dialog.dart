// card_dialog.dart
import 'package:flutter/material.dart';

void showCardDialog(BuildContext context, int index) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Card #${index + 1} Clicked'),
      content: Text('You clicked on Card #${index + 1}'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
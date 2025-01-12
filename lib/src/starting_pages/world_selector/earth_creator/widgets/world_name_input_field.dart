import 'package:flutter/material.dart';

class WorldNameInputField extends StatelessWidget {
  final TextEditingController controller;

  const WorldNameInputField({required this.controller, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: screenWidth * 0.3,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'World Name',
              border: UnderlineInputBorder(),
            ),
          ),
        ),
      ),
    );
  }
}
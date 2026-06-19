import 'package:flutter/material.dart';

class WarliBackground extends StatelessWidget {
  final Widget child;
  const WarliBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/background.png',
          fit: BoxFit.cover,
        ),
        child,
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/colors.dart';

class BrownButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final double? width;

  const BrownButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 240,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kButtonBrown,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontFamily: 'Georgia',
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

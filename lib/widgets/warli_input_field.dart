import 'package:flutter/material.dart';
import '../constants/colors.dart';

class WarliInputField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const WarliInputField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: kBorderBrown, width: 2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: kMedBrown, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kMedBrown),
          hintText: hint,
          hintStyle: const TextStyle(color: kMedBrown),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade700, // change theme color
          side: BorderSide(color: Colors.blue.shade700, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class VuMeter extends StatelessWidget {
  const VuMeter({super.key, required this.level});
  final double level; // 0..1
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: (level.clamp(0, 1) as double) * 200,
          width: double.infinity,
          color: Colors.black87,
        ),
      ),
    );
  }
}

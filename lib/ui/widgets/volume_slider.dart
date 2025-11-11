import 'package:flutter/material.dart';

class VolumeSlider extends StatelessWidget {
  const VolumeSlider({super.key, required this.value, required this.onChanged});
  final double value; // 0..1
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RotatedBox(
          quarterTurns: 3,
          child: Slider(value: value, onChanged: onChanged, min: 0, max: 1),
        ),
        const SizedBox(height: 8),
        const Text('Volume', style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

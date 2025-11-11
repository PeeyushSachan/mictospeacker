import 'package:flutter/material.dart';
import '../../feature/audio/dsp_params.dart';

class EqCard extends StatelessWidget {
  const EqCard({super.key, required this.gains, required this.onChange});
  final List<double> gains; // length 5
  final void Function(int idx, double gain) onChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Equalizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (i) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: gains[i],
                          min: -12, max: 12, divisions: 24,
                          label: '${gains[i].toStringAsFixed(0)} dB',
                          onChanged: (v) => onChange(i, v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${defaultFrequencies[i]}'),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

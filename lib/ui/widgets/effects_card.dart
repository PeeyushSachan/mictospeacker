import 'package:flutter/material.dart';

class EffectsCard extends StatelessWidget {
  const EffectsCard({
    super.key,
    required this.pitch,
    required this.onPitch,
    required this.formant,
    required this.onFormant,
    required this.reverb,
    required this.onReverb,
    required this.reverbWet,
    required this.onReverbWet,
    required this.echo,
    required this.onEcho,
    required this.echoDelay,
    required this.onEchoDelay,
    required this.echoFeedback,
    required this.onEchoFeedback,
  });

  final double pitch;
  final ValueChanged<double> onPitch;
  final int formant;
  final ValueChanged<int> onFormant;
  final bool reverb;
  final ValueChanged<bool> onReverb;
  final double reverbWet;
  final ValueChanged<double> onReverbWet;
  final bool echo;
  final ValueChanged<bool> onEcho;
  final int echoDelay;
  final ValueChanged<int> onEchoDelay;
  final double echoFeedback;
  final ValueChanged<double> onEchoFeedback;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice Effects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _labeled(
              'Pitch (${pitch.toStringAsFixed(2)}×)',
              Slider(value: pitch, min: 0.5, max: 2.0, onChanged: onPitch),
            ),
            _labeled(
              'Formant/Bass ($formant)',
              Slider(
                value: formant.toDouble(),
                min: -12,
                max: 12,
                divisions: 24,
                label: '$formant',
                onChanged: (v) => onFormant(v.round()),
              ),
            ),
            Row(
              children: [
                Switch(value: reverb, onChanged: onReverb),
                const Text('Reverb'),
              ],
            ),
            if (reverb)
              _labeled(
                'Reverb Wet (${(reverbWet * 100).round()}%)',
                Slider(
                  value: reverbWet,
                  min: 0,
                  max: 1,
                  onChanged: onReverbWet,
                ),
              ),
            Row(
              children: [
                Switch(value: echo, onChanged: onEcho),
                const Text('Echo'),
              ],
            ),
            if (echo) ...[
              _labeled(
                'Delay ($echoDelay ms)',
                Slider(
                  value: echoDelay.toDouble(),
                  min: 50,
                  max: 800,
                  divisions: 15,
                  onChanged: (v) => onEchoDelay(v.round()),
                ),
              ),
              _labeled(
                'Feedback (${(echoFeedback * 100).round()}%)',
                Slider(
                  value: echoFeedback,
                  min: 0,
                  max: 0.95,
                  onChanged: onEchoFeedback,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labeled(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      child,
      const SizedBox(height: 8),
    ],
  );
}

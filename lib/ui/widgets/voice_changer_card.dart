import 'package:flutter/material.dart';
import '../../feature/audio/audio_state.dart';

class VoiceChangerCard extends StatelessWidget {
  const VoiceChangerCard({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final VoicePreset selected;
  final ValueChanged<VoicePreset> onSelected;

  static const _accent = Color(0xFF2ECC71);

  @override
  Widget build(BuildContext context) {
    final presets = [
      _VoicePresetMeta(VoicePreset.child, '👶 Child', Icons.child_care),
      _VoicePresetMeta(
        VoicePreset.funny,
        '😂 Funny',
        Icons.sentiment_satisfied_alt,
      ),
      _VoicePresetMeta(VoicePreset.robot, '🤖 Robot', Icons.smart_toy),
      _VoicePresetMeta(VoicePreset.deep, '🧔 Deep', Icons.record_voice_over),
      _VoicePresetMeta(VoicePreset.alien, '👽 Alien', Icons.travel_explore),
      _VoicePresetMeta(VoicePreset.normal, '🎧 Normal', Icons.headphones),
    ];
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice Changer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((meta) {
                  final active = meta.preset == selected;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: active,
                      label: Text(meta.label),
                      avatar: Icon(
                        meta.icon,
                        size: 18,
                        color: active ? Colors.white : Colors.black87,
                      ),
                      selectedColor: _accent,
                      labelStyle: TextStyle(
                        color: active ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => onSelected(meta.preset),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePresetMeta {
  const _VoicePresetMeta(this.preset, this.label, this.icon);
  final VoicePreset preset;
  final String label;
  final IconData icon;
}

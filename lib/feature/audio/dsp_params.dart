class EqBand {
  EqBand(this.freq, this.gainDb);
  final int freq; // Hz
  final double gainDb;
  Map<String, dynamic> toJson() => {'freq': freq, 'gainDb': gainDb};
}

class DspParams {
  DspParams({
    required this.eqBands,
    required this.pitch,
    required this.formant,
    required this.reverb,
    required this.reverbWet,
    required this.echo,
    required this.echoDelayMs,
    required this.echoFeedback,
    required this.volume,
    required this.voicePreset,
  });
  final List<EqBand> eqBands;
  final double pitch;
  final int formant;
  final bool reverb;
  final double reverbWet;
  final bool echo;
  final int echoDelayMs;
  final double echoFeedback;
  final double volume;
  final String voicePreset;

  Map<String, dynamic> toJson() => {
    'eq': eqBands.map((e) => e.toJson()).toList(),
    'pitch': pitch,
    'formant': formant,
    'reverb': reverb,
    'reverbWet': reverbWet,
    'echo': echo,
    'echoDelayMs': echoDelayMs,
    'echoFeedback': echoFeedback,
    'volume': volume,
    'voicePreset': voicePreset,
  };
}

const defaultFrequencies = [60, 230, 910, 3600, 14000];

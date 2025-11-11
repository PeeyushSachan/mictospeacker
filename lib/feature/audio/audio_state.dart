import 'package:equatable/equatable.dart';

class AudioState extends Equatable {
  final bool isRunning;
  final double volume; // 0..1
  final List<double> eqGains; // 5 bands, in dB
  final double pitch; // 0.5..2.0
  final int formant; // -12..+12 (approx bass/formant)
  final bool reverb;
  final double reverbWet; // 0..1
  final bool echo;
  final int echoDelayMs;
  final double echoFeedback; // 0..0.95
  final double inputLevel; // 0..1 visual only
  const AudioState({
    this.isRunning = false,
    this.volume = 1.0,
    this.eqGains = const [0,0,0,0,0],
    this.pitch = 1.0,
    this.formant = 0,
    this.reverb = false,
    this.reverbWet = 0.25,
    this.echo = false,
    this.echoDelayMs = 240,
    this.echoFeedback = 0.35,
    this.inputLevel = 0.0,
  });

  AudioState copyWith({
    bool? isRunning,
    double? volume,
    List<double>? eqGains,
    double? pitch,
    int? formant,
    bool? reverb,
    double? reverbWet,
    bool? echo,
    int? echoDelayMs,
    double? echoFeedback,
    double? inputLevel,
  }) => AudioState(
    isRunning: isRunning ?? this.isRunning,
    volume: volume ?? this.volume,
    eqGains: eqGains ?? this.eqGains,
    pitch: pitch ?? this.pitch,
    formant: formant ?? this.formant,
    reverb: reverb ?? this.reverb,
    reverbWet: reverbWet ?? this.reverbWet,
    echo: echo ?? this.echo,
    echoDelayMs: echoDelayMs ?? this.echoDelayMs,
    echoFeedback: echoFeedback ?? this.echoFeedback,
    inputLevel: inputLevel ?? this.inputLevel,
  );

  @override
  List<Object?> get props => [isRunning, volume, eqGains, pitch, formant, reverb, reverbWet, echo, echoDelayMs, echoFeedback, inputLevel];
}

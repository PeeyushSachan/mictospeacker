import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_state.dart';
import 'dsp_params.dart';
import 'platform_audio.dart';

final audioControllerProvider =
    StateNotifierProvider<AudioController, AudioState>(
      (ref) => AudioController(),
    );

class AudioController extends StateNotifier<AudioState> {
  AudioController() : super(const AudioState()) {
    _levelSub = PlatformAudio.inputLevelStream.listen((lv) {
      state = state.copyWith(inputLevel: lv);
    }, onError: (_) {});
  }
  StreamSubscription<double>? _levelSub;
  Timer? _debounce;

  Future<void> toggle() async {
    if (state.isRunning) {
      await PlatformAudio.stop();
      state = state.copyWith(isRunning: false, inputLevel: 0, isSyncing: false);
    } else {
      final allowed = await _ensureMicPermission();
      if (!allowed) return;
      try {
        final ok = await PlatformAudio.start();
        state = state.copyWith(isRunning: ok);
        if (ok) {
          state = state.copyWith(isSyncing: true);
          _pushParams();
        }
      } on PlatformException {
        state = state.copyWith(
          isRunning: false,
          inputLevel: 0,
          isSyncing: false,
        );
      } catch (_) {
        state = state.copyWith(
          isRunning: false,
          inputLevel: 0,
          isSyncing: false,
        );
      }
    }
  }

  void setVolume(double v) => _update(() => state = state.copyWith(volume: v));
  void setEq(int idx, double gainDb) {
    final g = List<double>.from(state.eqGains);
    g[idx] = gainDb;
    _update(() => state = state.copyWith(eqGains: g));
  }

  void setPitch(double p) => _update(() => state = state.copyWith(pitch: p));
  void setFormant(int f) => _update(() => state = state.copyWith(formant: f));
  void setReverb(bool on) => _update(() => state = state.copyWith(reverb: on));
  void setReverbWet(double w) =>
      _update(() => state = state.copyWith(reverbWet: w));
  void setEcho(bool on) => _update(() => state = state.copyWith(echo: on));
  void setEchoDelay(int ms) =>
      _update(() => state = state.copyWith(echoDelayMs: ms));
  void setEchoFeedback(double fb) =>
      _update(() => state = state.copyWith(echoFeedback: fb));
  void setVoicePreset(VoicePreset preset) {
    _update(() {
      state = state.copyWith(
        voicePreset: preset,
        pitch: _pitchForPreset(preset),
        formant: _formantForPreset(preset),
        reverb: _reverbEnabled(preset),
        reverbWet: _reverbWetForPreset(preset),
        echo: _echoEnabled(preset),
        echoDelayMs: _echoDelayForPreset(preset),
        echoFeedback: _echoFeedbackForPreset(preset),
        eqGains: _eqForPreset(preset),
      );
    });
  }

  double _pitchForPreset(VoicePreset preset) => switch (preset) {
    VoicePreset.child => 1.55,
    VoicePreset.funny => 1.35,
    VoicePreset.robot => 1.0,
    VoicePreset.deep => 0.72,
    VoicePreset.alien => 1.2,
    VoicePreset.normal => 1.0,
  };

  int _formantForPreset(VoicePreset preset) => switch (preset) {
    VoicePreset.child => -4,
    VoicePreset.funny => -2,
    VoicePreset.robot => 0,
    VoicePreset.deep => 5,
    VoicePreset.alien => -6,
    VoicePreset.normal => 0,
  };

  bool _reverbEnabled(VoicePreset preset) =>
      preset == VoicePreset.child ||
      preset == VoicePreset.robot ||
      preset == VoicePreset.alien ||
      preset == VoicePreset.deep;

  double _reverbWetForPreset(VoicePreset preset) => switch (preset) {
    VoicePreset.child => 0.25,
    VoicePreset.robot => 0.4,
    VoicePreset.deep => 0.18,
    VoicePreset.alien => 0.35,
    _ => 0.0,
  };

  bool _echoEnabled(VoicePreset preset) =>
      preset == VoicePreset.funny ||
      preset == VoicePreset.robot ||
      preset == VoicePreset.alien;

  int _echoDelayForPreset(VoicePreset preset) => switch (preset) {
    VoicePreset.funny => 120,
    VoicePreset.robot => 220,
    VoicePreset.alien => 260,
    _ => 180,
  };

  double _echoFeedbackForPreset(VoicePreset preset) => switch (preset) {
    VoicePreset.funny => 0.25,
    VoicePreset.robot => 0.45,
    VoicePreset.alien => 0.3,
    _ => 0.2,
  };

  List<double> _eqForPreset(VoicePreset preset) {
    switch (preset) {
      case VoicePreset.child:
        return const [2, 1, 0, -1, 3];
      case VoicePreset.funny:
        return const [0, -1, 2, 1, -1];
      case VoicePreset.robot:
        return const [1, 2, 4, 2, -2];
      case VoicePreset.deep:
        return const [4, 3, 0, -3, -4];
      case VoicePreset.alien:
        return const [-1, 0, 3, 4, 1];
      case VoicePreset.normal:
        return const [0, 0, 0, 0, 0];
    }
  }

  void _update(void Function() fn) {
    fn();
    state = state.copyWith(isSyncing: true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), _pushParams);
  }

  Future<void> _pushParams() async {
    final params = DspParams(
      eqBands: List.generate(
        5,
        (i) => EqBand(defaultFrequencies[i], state.eqGains[i]),
      ),
      pitch: state.pitch,
      formant: state.formant,
      reverb: state.reverb,
      reverbWet: state.reverbWet,
      echo: state.echo,
      echoDelayMs: state.echoDelayMs,
      echoFeedback: state.echoFeedback,
      volume: state.volume,
      voicePreset: state.voicePreset.name,
    );
    try {
      await PlatformAudio.apply(params);
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return false;
    status = await Permission.microphone.request();
    return status.isGranted || status.isLimited;
  }

  @override
  void dispose() {
    _levelSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

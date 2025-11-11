import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_state.dart';
import 'dsp_params.dart';
import 'platform_audio.dart';

final audioControllerProvider =
    StateNotifierProvider<AudioController, AudioState>((ref) => AudioController());

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
      state = state.copyWith(isRunning: false, inputLevel: 0);
    } else {
      final allowed = await _ensureMicPermission();
      if (!allowed) return;
      try {
        final ok = await PlatformAudio.start();
        state = state.copyWith(isRunning: ok);
        if (ok) _pushParams();
      } on PlatformException {
        state = state.copyWith(isRunning: false, inputLevel: 0);
      } catch (_) {
        state = state.copyWith(isRunning: false, inputLevel: 0);
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
  void setReverbWet(double w) => _update(() => state = state.copyWith(reverbWet: w));
  void setEcho(bool on) => _update(() => state = state.copyWith(echo: on));
  void setEchoDelay(int ms) => _update(() => state = state.copyWith(echoDelayMs: ms));
  void setEchoFeedback(double fb) => _update(() => state = state.copyWith(echoFeedback: fb));

  void _update(void Function() fn) {
    fn();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), _pushParams);
  }

  Future<void> _pushParams() async {
    final params = DspParams(
      eqBands: List.generate(5, (i) => EqBand(defaultFrequencies[i], state.eqGains[i])),
      pitch: state.pitch,
      formant: state.formant,
      reverb: state.reverb,
      reverbWet: state.reverbWet,
      echo: state.echo,
      echoDelayMs: state.echoDelayMs,
      echoFeedback: state.echoFeedback,
      volume: state.volume,
    );
    await PlatformAudio.apply(params);
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

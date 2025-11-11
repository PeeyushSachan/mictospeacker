import 'dart:async';
import 'package:flutter/services.dart';
import 'dsp_params.dart';

class PlatformAudio {
  static const MethodChannel _ch = MethodChannel('mic_to_speaker/audio');
  static const EventChannel _level = EventChannel('mic_to_speaker/level');

  static Stream<double> get inputLevelStream =>
      _level.receiveBroadcastStream().map((e) => (e as num).toDouble());

  static Future<bool> start() async {
    final ok = await _ch.invokeMethod<bool>('start');
    return ok ?? false;
  }

  static Future<void> stop() async {
    await _ch.invokeMethod('stop');
  }

  static Future<void> apply(DspParams params) async {
    await _ch.invokeMethod('apply', params.toJson());
  }
}

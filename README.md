# Mic to Speaker (Scaffold)

This repository contains a **Flutter + native bridge scaffold** for a *Mic to Speaker* app featuring:
- UI for mic start/stop, volume, 5‑band EQ, and a Voice Effects section (pitch, formant/bass, reverb, echo).
- Riverpod state and debounced parameter pushes to native audio engine.
- MethodChannel stubs on Android/iOS + an **input level mock stream** so the UI runs.

> Native low‑latency audio engine is marked as TODO in platform sources. Wire your DSP there.

## Run UI (mocked levels)
1. Add `pubspec.yaml` with dependencies: `flutter_riverpod`, `go_router`.
2. `flutter run` — the mic button starts/stops mocked levels.

## Where to implement audio
- **Android:** `android/.../audio/AudioEngine.kt` (AudioRecord → DSP → AudioTrack).
- **iOS:** `ios/Runner/Audio/AudioEngine.swift` (AVAudioEngine).

## Frequencies
`60, 230, 910, 3600, 14000 Hz`

## License
MIT
# mictospeacker

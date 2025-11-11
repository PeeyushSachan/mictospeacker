// lib/ui/home_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../feature/audio/audio_controller.dart';
import 'widgets/mic_button.dart';
import 'widgets/vu_meter.dart';
import 'widgets/volume_slider.dart';
import 'widgets/eq_card.dart';
import 'widgets/effects_card.dart';
import 'widgets/voice_changer_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  MicPosition pos = MicPosition.back;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              // TODO: handle menu actions
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'rate', child: Text('Rate this app')),
              PopupMenuItem(value: 'share', child: Text('Share this app')),
              PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Mic position selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      DropdownButton<MicPosition>(
                        value: pos,
                        items: MicPosition.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => pos = v ?? pos),
                      ),
                    ],
                  ),
                ),
              ),

              // Meter + Mic button + Volume
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      VuMeter(level: state.inputLevel),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            MicButton(
                              isOn: state.isRunning,
                              onTap: controller.toggle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.isRunning
                                  ? 'Listening… Tap to Stop'
                                  : 'Press to Start',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      VolumeSlider(
                        value: state.volume,
                        onChanged: controller.setVolume,
                      ),
                    ],
                  ),
                ),
              ),

              // Equalizer
              SliverToBoxAdapter(
                child: EqCard(gains: state.eqGains, onChange: controller.setEq),
              ),

              // Voice preset quick picker
              SliverToBoxAdapter(
                child: VoiceChangerCard(
                  selected: state.voicePreset,
                  onSelected: controller.setVoicePreset,
                ),
              ),

              // Pinned sticky header (SAFE)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  minHeight: 44,
                  maxHeight: 52,
                  // Put your header content here; it will be constrained by the delegate.
                  childBuilder: (context, shrinkOffset, overlaps) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Voice Effects',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Effects controls
              SliverToBoxAdapter(
                child: EffectsCard(
                  pitch: state.pitch,
                  onPitch: controller.setPitch,
                  formant: state.formant,
                  onFormant: controller.setFormant,
                  reverb: state.reverb,
                  onReverb: controller.setReverb,
                  reverbWet: state.reverbWet,
                  onReverbWet: controller.setReverbWet,
                  echo: state.echo,
                  onEcho: controller.setEcho,
                  echoDelay: state.echoDelayMs,
                  onEchoDelay: controller.setEchoDelay,
                  echoFeedback: state.echoFeedback,
                  onEchoFeedback: controller.setEchoFeedback,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),

          // Syncing HUD
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: state.isSyncing ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !state.isSyncing,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Syncing changes…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A safe sticky header that guarantees the sliver's claimed extents
/// match the actual laid-out height, preventing sliver geometry assertions.
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.childBuilder,
  }) : assert(minHeight > 0),
       assert(maxHeight >= minHeight);

  final double minHeight;
  final double maxHeight;

  /// Build the *contents* of the header. The delegate will size/position it.
  final Widget Function(
    BuildContext context,
    double shrinkOffset,
    bool overlaps,
  )
  childBuilder;

  double get _effectiveMin => minHeight;
  double get _effectiveMax => math.max(minHeight, maxHeight);

  @override
  double get minExtent => _effectiveMin;

  @override
  double get maxExtent => _effectiveMax;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Current height clamped between max → min while scrolling.
    final currentExtent = (_effectiveMax - shrinkOffset).clamp(
      _effectiveMin,
      _effectiveMax,
    );

    // Ensure the child never exceeds the space this sliver claims.
    return SizedBox(
      height: currentExtent,
      width: double.infinity,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: childBuilder(context, shrinkOffset, overlapsContent),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate old) {
    // Rebuild if sizing or builder identity changes.
    return old.minHeight != minHeight ||
        old.maxHeight != maxHeight ||
        old.childBuilder != childBuilder;
  }
}

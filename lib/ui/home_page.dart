import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../feature/audio/audio_controller.dart';
import '../feature/audio/audio_state.dart';
import 'widgets/mic_button.dart';
import 'widgets/vu_meter.dart';
import 'widgets/volume_slider.dart';
import 'widgets/eq_card.dart';
import 'widgets/effects_card.dart';

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
              // Placeholder actions
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'rate', child: Text('Rate this app')),
              PopupMenuItem(value: 'share', child: Text('Share this app')),
              PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
            ],
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  DropdownButton<MicPosition>(
                    value: pos,
                    items: MicPosition.values.map((e) =>
                      DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                    onChanged: (v) => setState(()=> pos = v ?? pos),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  VuMeter(level: state.inputLevel),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        MicButton(isOn: state.isRunning, onTap: controller.toggle),
                        const SizedBox(height: 8),
                        Text(state.isRunning ? 'Listening… Tap to Stop' : 'Press to Start',
                          style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  VolumeSlider(value: state.volume, onChanged: controller.setVolume),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: EqCard(
              gains: state.eqGains,
              onChange: controller.setEq,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text('Voice Effects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              minExtent: 44, maxExtent: 52,
            ),
          ),
          SliverToBoxAdapter(
            child: EffectsCard(
              pitch: state.pitch, onPitch: controller.setPitch,
              formant: state.formant, onFormant: controller.setFormant,
              reverb: state.reverb, onReverb: controller.setReverb,
              reverbWet: state.reverbWet, onReverbWet: controller.setReverbWet,
              echo: state.echo, onEcho: controller.setEcho,
              echoDelay: state.echoDelayMs, onEchoDelay: controller.setEchoDelay,
              echoFeedback: state.echoFeedback, onEchoFeedback: controller.setEchoFeedback,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.child, required this.minExtent, required this.maxExtent});
  final Widget child;
  @override
  final double minExtent;
  @override
  final double maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => false;
}

import 'package:flutter/material.dart';
import '../../feature/audio/audio_state.dart';

class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.isOn, required this.onTap});
  final bool isOn;
  final VoidCallback onTap;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 160, height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 150, height: 150,
              decoration: BoxDecoration(
                color: widget.isOn ? const Color(0xFF2ECC71) : Colors.transparent,
                border: Border.all(color: const Color(0xFF2ECC71), width: 8),
                shape: BoxShape.circle,
              ),
            ),
            if (widget.isOn)
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
                child: const SizedBox(width: 150, height: 150),
              ),
            const Icon(Icons.mic, size: 64, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}

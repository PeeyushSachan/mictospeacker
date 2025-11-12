// Configure microphone permission prompts before using this screen:
// - Android: add `<uses-permission android:name="android.permission.RECORD_AUDIO" />`
//   inside `android/app/src/main/AndroidManifest.xml`.
// - iOS: add an `NSMicrophoneUsageDescription` entry to `ios/Runner/Info.plist`.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mic_to_speaker/ads/ads.dart';
import 'package:permission_handler/permission_handler.dart';

import 'home_page.dart';

const _primaryColor = Color(0xFF5B86E5);
const _secondaryColor = Color(0xFF36D1DC);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _bgController;
  late final AnimationController _waveController;

  PermissionStatus? _micStatus;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bgController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (!mounted) return;
    setState(() => _micStatus = status);
    if (status.isGranted) {
      _scheduleNavigation();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    setState(() => _micStatus = status);
    if (status.isGranted) {
      _scheduleNavigation();
    }
  }

  void _scheduleNavigation() {
    if (_navigated) return;
    _navigated = true;
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ExitAdGuard(child: HomePage())));
    });
  }

  bool get _isPermanentlyDenied {
    final status = _micStatus;
    if (status == null) return false;
    return status.isPermanentlyDenied || status.isRestricted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseController,
          _bgController,
          _waveController,
        ]),
        builder: (context, _) {
          final bgColors = _buildGradientColors(theme.brightness);
          final alignment =
              AlignmentTween(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).transform(_bgController.value) ??
              Alignment.center;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: alignment,
                end: alignment.add(const Alignment(0.2, -0.2)),
                colors: bgColors,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WavePainter(
                      progress: _waveController.value,
                      color: colorScheme.onPrimary.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.2),
                        radius: 1.2 + (_pulseController.value * 0.2),
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: 0.94 + (_pulseController.value * 0.12),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          child: _buildLogo(theme),
                        ),
                        const SizedBox(height: 32),
                        _buildPermissionArea(theme),
                        const Spacer(),
                        _buildFooterIndicator(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    final textStyle =
        theme.textTheme.displayMedium ??
        const TextStyle(fontSize: 48, fontWeight: FontWeight.bold);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: _secondaryColor.withOpacity(0.6),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
            gradient: const LinearGradient(
              colors: [_secondaryColor, _primaryColor],
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'Micky',
              style: textStyle.copyWith(
                color: Colors.white,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: 0.9,
          child: Text(
            'mic to speaker & voice changer',
            style:
                theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ) ??
                const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionArea(ThemeData theme) {
    final status = _micStatus;
    final textColor = theme.colorScheme.onPrimaryContainer.withOpacity(0.85);

    if (status == null) {
      return _InfoCard(
        title: 'Checking microphone access…',
        description: 'We’re making sure Micky can listen before jumping in.',
        trailing: const CircularProgressIndicator.adaptive(),
      );
    }

    if (status.isGranted) {
      return _InfoCard(
        title: 'All set!',
        description: 'Microphone ready. Preparing amazing voice effects…',
        trailing: const Icon(Icons.check_circle, color: Colors.white),
      );
    }

    if (_isPermanentlyDenied) {
      return Column(
        children: [
          _InfoCard(
            title: 'Microphone blocked',
            description:
                'Allow mic access from system settings to enable live effects.',
            trailing: Icon(Icons.mic_off_rounded, color: textColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primaryColor,
                  ),
                  onPressed: _scheduleNavigation,
                  child: const Text('Continue without mic'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        _InfoCard(
          title: 'Microphone permission needed',
          description:
              'Micky needs mic access to stream your voice to the speaker.',
          trailing: Icon(Icons.mic_none_rounded, color: textColor),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryColor,
            ),
            onPressed: _requestPermission,
            child: const Text('Allow Mic Access'),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterIndicator(ThemeData theme) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,
      letterSpacing: 0.5,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Warming up live audio engine…', style: textStyle),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 6,
            color: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  List<Color> _buildGradientColors(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [_primaryColor.withOpacity(0.9), _secondaryColor.withOpacity(0.9)];
    }
    return [_secondaryColor.withOpacity(0.9), _primaryColor.withOpacity(0.95)];
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.description,
    this.trailing,
  });

  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    for (int i = 0; i < 3; i++) {
      final phase = progress + (i * 0.2);
      final path = _buildWavePath(size, phase, amplitude: 10 + (i * 6));
      canvas.drawPath(
        path,
        paint..color = color.withOpacity((0.3 - (i * 0.08)).clamp(0, 1)),
      );
    }
  }

  Path _buildWavePath(Size size, double phase, {double amplitude = 12}) {
    final path = Path();
    final baseHeight = size.height * 0.5;

    path.moveTo(0, baseHeight);
    for (double x = 0; x <= size.width; x++) {
      final y =
          baseHeight +
          math.sin((x / size.width * 2 * math.pi * 2) + (phase * 2 * math.pi)) *
              amplitude;
      path.lineTo(x, y);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

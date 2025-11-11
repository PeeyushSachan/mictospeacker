import 'package:flutter/material.dart';

class AppColors {
  static const Color accent = Color(0xFF2ECC71);
  static const Color bg = Colors.white;
  static const Color text = Colors.black87;
  static const Color card = Color(0xFFF7F7F7);
}

class AppStrings {
  static const appName = 'Mic to Speaker';
  static const rateUrl = 'https://example.com/rate';
  static const shareText = 'Try Mic to Speaker: Realtime mic monitor with EQ & effects';
  static const privacyUrl = 'https://example.com/privacy';
}

enum MicPosition { bottom, back }

extension MicPositionLabel on MicPosition {
  String get label => this == MicPosition.bottom ? 'Mobile - Bottom' : 'Mobile - Back';
}

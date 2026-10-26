import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Lightweight sound helper — preloads and plays short sound effects.
class SoundService {
  SoundService._();
  static final instance = SoundService._();

  AudioPlayer? _player;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      _player = AudioPlayer();
      await _player!.setSource(AssetSource('sounds/water_drip.wav'));
      await _player!.setVolume(0.6);
      _ready = true;
    } catch (_) {
      // Audio not available — silently degrade.
    }
  }

  /// Play the water drip sound + light haptic. Non-blocking, never throws.
  Future<void> playWaterDrip() async {
    HapticFeedback.lightImpact();
    if (!_ready || _player == null) return;
    try {
      await _player!.stop();
      await _player!.play(AssetSource('sounds/water_drip.wav'));
    } catch (_) {
      // Graceful — glass still gets added even if audio fails.
    }
  }
}

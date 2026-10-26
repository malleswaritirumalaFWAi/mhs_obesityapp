import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_colors.dart';

/// A mic button that records speech and appends transcribed text to a controller.
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  bool _initialised = false;

  Future<void> _ensureInit() async {
    if (_initialised) return;
    _available = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    _initialised = true;
  }

  Future<void> _toggle() async {
    await _ensureInit();
    if (!_available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device.')),
        );
      }
      return;
    }

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isEmpty) return;
        final ctrl = widget.controller;
        final existing = ctrl.text;
        // Append to existing text with a space separator.
        if (existing.isNotEmpty && !existing.endsWith(' ')) {
          ctrl.text = '$existing $text';
        } else {
          ctrl.text = '$existing$text';
        }
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _listening
              ? AppColors.coral
              : AppColors.coral.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _listening ? Symbols.stop_rounded : Symbols.mic_rounded,
          color: _listening ? Colors.white : AppColors.coral,
          size: 22,
          fill: 1,
        ),
      ),
    );
  }
}

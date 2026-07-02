import 'package:flutter/material.dart';

/// Neumorphic palette — FitQuest v2 "Soft Neumorphic Light" design system.
/// Matches style.css from the v2_neumorphic HTML prototype exactly.
class AppColors {
  AppColors._();

  // Surfaces — warm cream matching v2 prototype
  static const bg = Color(0xFFF2EFE9);
  static const surface = Color(0xFFF5F3EF);
  static const shadowDark = Color(0xFFD9D4CA);
  static const shadowLight = Color(0xFFFFFFFF);
  static const line = Color(0xFFE5DDD0);

  // Accents — v2 palette
  static const coral = Color(0xFFFF7A6B);
  static const coralSoft = Color(0xFFFFE6E1);

  static const sage = Color(0xFF8BC4A9);
  static const sageSoft = Color(0xFFDDEFE4);
  static const sageDark = Color(0xFF2E6B4F);

  static const gold = Color(0xFFE5B36A);
  static const goldSoft = Color(0xFFFFF3DC);
  static const goldDark = Color(0xFFA36F1A);

  static const berry = Color(0xFFB788D9);
  static const berrySoft = Color(0xFFEFE3F7);
  static const berryDark = Color(0xFF7B4FA0);

  // Ink (text)
  static const ink = Color(0xFF2B2A28);
  static const inkMid = Color(0xFF4B4945);
  static const inkSoft = Color(0xFF6B6863);

  // Legacy aliases — mapped to v2 coral so existing references stay warm
  static const orange = coral;
  static const amber = gold;
  static const teal = sageDark;
  static const tealLight = sage;
  static const orangeSoft = coralSoft;

  // Neu-friendly accent gradients (coral → berry warm wash)
  static const LinearGradient orangeGrad = LinearGradient(
    colors: [coral, berry],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient tealGrad = LinearGradient(
    colors: [sageDark, sage],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGrad = LinearGradient(
    colors: [coral, berry],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

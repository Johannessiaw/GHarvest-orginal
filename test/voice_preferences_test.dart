/// Tests for VoicePreferences — continuousMode field, shouldAutoSpeak logic,
/// copyWith, load/save round-trip (with SharedPreferences mock).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gharvest/voice_preferences.dart';

void main() {
  // ── SharedPreferences mock setup ─────────────────────────────────────────
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 1. Default values
  // ══════════════════════════════════════════════════════════════════════════
  group('Default values', () {
    test('continuousMode defaults to false', () {
      const prefs = VoicePreferences();
      expect(prefs.continuousMode, isFalse);
    });

    test('shouldAutoSpeak is false with all defaults', () {
      const prefs = VoicePreferences();
      expect(prefs.shouldAutoSpeak, isFalse);
    });

    test('mode defaults to textOnly', () {
      const prefs = VoicePreferences();
      expect(prefs.mode, VoiceInteractionMode.textOnly);
    });

    test('autoSpeak defaults to false', () {
      const prefs = VoicePreferences();
      expect(prefs.autoSpeak, isFalse);
    });

    test('manualReplayEnabled defaults to true', () {
      const prefs = VoicePreferences();
      expect(prefs.manualReplayEnabled, isTrue);
    });

    test('defaultLanguage defaults to en-GH', () {
      const prefs = VoicePreferences();
      expect(prefs.defaultLanguage, 'en-GH');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. shouldAutoSpeak logic
  // ══════════════════════════════════════════════════════════════════════════
  group('shouldAutoSpeak', () {
    test('true when continuousMode is true', () {
      const prefs = VoicePreferences(continuousMode: true);
      expect(prefs.shouldAutoSpeak, isTrue);
    });

    test('true when mode is voiceFirst', () {
      const prefs = VoicePreferences(
        mode: VoiceInteractionMode.voiceFirst,
      );
      expect(prefs.shouldAutoSpeak, isTrue);
    });

    test('true when autoSpeak is true', () {
      const prefs = VoicePreferences(autoSpeak: true);
      expect(prefs.shouldAutoSpeak, isTrue);
    });

    test('false when all three conditions are false', () {
      const prefs = VoicePreferences(
        mode: VoiceInteractionMode.textOnly,
        autoSpeak: false,
        continuousMode: false,
      );
      expect(prefs.shouldAutoSpeak, isFalse);
    });

    test('mixed mode alone does not enable shouldAutoSpeak', () {
      const prefs = VoicePreferences(
        mode: VoiceInteractionMode.mixed,
        autoSpeak: false,
        continuousMode: false,
      );
      expect(prefs.shouldAutoSpeak, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. copyWith
  // ══════════════════════════════════════════════════════════════════════════
  group('copyWith', () {
    test('can enable continuousMode via copyWith', () {
      const original = VoicePreferences();
      final updated = original.copyWith(continuousMode: true);
      expect(updated.continuousMode, isTrue);
      // Other fields unchanged.
      expect(updated.mode, original.mode);
      expect(updated.autoSpeak, original.autoSpeak);
      expect(updated.defaultLanguage, original.defaultLanguage);
    });

    test('does not mutate original', () {
      const original = VoicePreferences();
      original.copyWith(continuousMode: true);
      expect(original.continuousMode, isFalse);
    });

    test('copyWith language preserves other fields', () {
      const original = VoicePreferences(continuousMode: true, autoSpeak: true);
      final updated = original.copyWith(defaultLanguage: 'tw');
      expect(updated.defaultLanguage, 'tw');
      expect(updated.continuousMode, isTrue);
      expect(updated.autoSpeak, isTrue);
    });

    test('copyWith with no arguments returns identical values', () {
      const original = VoicePreferences(
        continuousMode: true,
        autoSpeak: true,
        defaultLanguage: 'tw',
        mode: VoiceInteractionMode.voiceFirst,
      );
      final copy = original.copyWith();
      expect(copy.continuousMode, original.continuousMode);
      expect(copy.autoSpeak, original.autoSpeak);
      expect(copy.defaultLanguage, original.defaultLanguage);
      expect(copy.mode, original.mode);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. Persistence — save / load round-trip
  // ══════════════════════════════════════════════════════════════════════════
  group('SharedPreferences round-trip', () {
    test('saves and loads continuousMode = true', () async {
      const prefs = VoicePreferences(continuousMode: true);
      await prefs.save();

      final loaded = await VoicePreferences.load();
      expect(loaded.continuousMode, isTrue);
    });

    test('saves and loads continuousMode = false', () async {
      const prefs = VoicePreferences(continuousMode: false);
      await prefs.save();

      final loaded = await VoicePreferences.load();
      expect(loaded.continuousMode, isFalse);
    });

    test('existing fields still round-trip correctly alongside continuousMode',
        () async {
      const prefs = VoicePreferences(
        mode: VoiceInteractionMode.voiceFirst,
        autoSpeak: true,
        manualReplayEnabled: false,
        defaultLanguage: 'tw',
        continuousMode: true,
      );
      await prefs.save();

      final loaded = await VoicePreferences.load();
      expect(loaded.mode, VoiceInteractionMode.voiceFirst);
      expect(loaded.autoSpeak, isTrue);
      expect(loaded.manualReplayEnabled, isFalse);
      expect(loaded.defaultLanguage, 'tw');
      expect(loaded.continuousMode, isTrue);
    });

    test('load returns defaults when no saved data exists', () async {
      // No prefs written — SharedPreferences is empty from setUp.
      final loaded = await VoicePreferences.load();
      expect(loaded.continuousMode, isFalse);
      expect(loaded.autoSpeak, isFalse);
      expect(loaded.manualReplayEnabled, isTrue);
      expect(loaded.defaultLanguage, 'en-GH');
      expect(loaded.mode, VoiceInteractionMode.textOnly);
    });

    test('overwriting a previous save works correctly', () async {
      const first = VoicePreferences(continuousMode: true, defaultLanguage: 'tw');
      await first.save();

      const second = VoicePreferences(continuousMode: false, defaultLanguage: 'en-GH');
      await second.save();

      final loaded = await VoicePreferences.load();
      expect(loaded.continuousMode, isFalse);
      expect(loaded.defaultLanguage, 'en-GH');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Backward compatibility — all pre-existing keys are unchanged
  // ══════════════════════════════════════════════════════════════════════════
  group('Backward compatibility', () {
    test('existing voice_mode key still loads correctly', () async {
      SharedPreferences.setMockInitialValues({
        'voice_mode': 'voiceFirst',
        'voice_auto_speak': true,
        'voice_manual_replay': false,
        'voice_default_language': 'tw',
        // No voice_continuous_mode — simulates old saved data.
      });

      final loaded = await VoicePreferences.load();
      expect(loaded.mode, VoiceInteractionMode.voiceFirst);
      expect(loaded.autoSpeak, isTrue);
      expect(loaded.manualReplayEnabled, isFalse);
      expect(loaded.defaultLanguage, 'tw');
      // New field defaults to false when absent from old data.
      expect(loaded.continuousMode, isFalse);
    });
  });
}

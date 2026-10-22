/// Tests for localAssistantAnswer() — the offline intent-parsing fallback.
///
/// Verifies that each intent category returns a non-empty response in both
/// English (en-GH) and Twi (tw), and that the default catch-all fires for
/// unknown prompts.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gharvest/services/ai_bridge_service.dart';

void main() {
  // ── Helper ──────────────────────────────────────────────────────────────
  void expectNonEmpty(String result, String label) {
    expect(result, isNotEmpty, reason: '$label returned empty string');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // English intents
  // ══════════════════════════════════════════════════════════════════════════
  group('English intents', () {
    test('price / market intent', () {
      final r = localAssistantAnswer('what is the price of tomatoes?');
      expectNonEmpty(r, 'price intent EN');
      expect(r, isNot(contains('Tell me what you need')));
    });

    test('buyer / seller intent', () {
      final r = localAssistantAnswer('I want to find buyers for my yam');
      expectNonEmpty(r, 'buyer intent EN');
    });

    test('transport intent', () {
      final r = localAssistantAnswer('I need a truck for delivery');
      expectNonEmpty(r, 'transport intent EN');
    });

    test('weather intent', () {
      final r = localAssistantAnswer('will it rain tomorrow?');
      expectNonEmpty(r, 'weather intent EN');
    });

    test('disease / pest intent', () {
      final r = localAssistantAnswer('my plant has yellow leaves');
      expectNonEmpty(r, 'disease intent EN');
    });

    test('order intent', () {
      final r = localAssistantAnswer('track my order delivery');
      expectNonEmpty(r, 'order intent EN');
    });

    test('unknown / catch-all intent', () {
      final r = localAssistantAnswer('hello there kofi');
      expectNonEmpty(r, 'catch-all EN');
    });

    test('empty prompt returns help prompt', () {
      final r = localAssistantAnswer('');
      expect(r, contains('Tell me what you need'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Twi intents
  // ══════════════════════════════════════════════════════════════════════════
  group('Twi intents (language: tw)', () {
    test('price intent returns Twi response', () {
      final r = localAssistantAnswer('tomato bo', language: 'tw');
      expectNonEmpty(r, 'price intent TW');
      // Should contain a Twi phrase.
      expect(r, contains('boɔ'));
    });

    test('buyer intent returns Twi response', () {
      final r = localAssistantAnswer('tɔfo', language: 'tw');
      expectNonEmpty(r, 'buyer intent TW');
    });

    test('transport intent returns Twi response', () {
      final r = localAssistantAnswer('kwan lorry', language: 'tw');
      expectNonEmpty(r, 'transport intent TW');
    });

    test('weather intent returns Twi response', () {
      final r = localAssistantAnswer('nsuo wiase', language: 'tw');
      expectNonEmpty(r, 'weather intent TW');
    });

    test('disease intent returns Twi response', () {
      final r = localAssistantAnswer('mmoawa leaf disease', language: 'tw');
      expectNonEmpty(r, 'disease intent TW');
    });

    test('order intent returns Twi response', () {
      final r = localAssistantAnswer('order delivery', language: 'tw');
      expectNonEmpty(r, 'order intent TW');
    });

    test('unknown intent returns Twi catch-all', () {
      final r = localAssistantAnswer('hello there', language: 'tw');
      expectNonEmpty(r, 'catch-all TW');
    });

    test('empty prompt in Twi returns Twi help prompt', () {
      final r = localAssistantAnswer('', language: 'tw');
      expect(r, contains('Ka asɛm'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Mixed / other language codes — fall through to English responses
  // ══════════════════════════════════════════════════════════════════════════
  group('Other language codes', () {
    test('non-tw language returns English response', () {
      final r = localAssistantAnswer('price tomato', language: 'ee');
      expectNonEmpty(r, 'Ewe code — English fallback');
    });
  });
}

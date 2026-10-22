import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gharvest/services/ai_bridge_service.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1. Backend URL resolution
  // ══════════════════════════════════════════════════════════════════════════
  group('GHarvest AI backend URL resolution', () {
    test('prefers the AI backend URL when configured', () {
      final result = resolveConfiguredBaseUrl(
        aiBackend: 'https://ai.example.com/',
        legacyBackend: 'https://legacy.example.com/',
      );

      expect(result, 'https://ai.example.com');
    });

    test(
      'falls back to the legacy backend URL when the AI setting is empty',
      () {
        final result = resolveConfiguredBaseUrl(
          aiBackend: '',
          legacyBackend: 'http://10.0.2.2:8000/',
        );

        expect(result, 'http://10.0.2.2:8000');
      },
    );

    test('supports the Voice/Kofi project backend URL define', () {
      final result = resolveConfiguredBaseUrl(
        aiBackend: '',
        legacyBackend: '',
        gHarvestBackend: 'http://127.0.0.1:8000/',
      );

      expect(result, 'http://127.0.0.1:8000');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. TtsAudio model — dialect/voice fields
  // ══════════════════════════════════════════════════════════════════════════
  group('TtsAudio routing metadata', () {
    test('carries provider, dialect and voice', () {
      final audio = TtsAudio(
        bytes: Uint8List.fromList([1, 2, 3]),
        provider: 'stable-twi-tts',
        dialect: 'asante',
        voice: 'twi-6',
      );
      expect(audio.provider, 'stable-twi-tts');
      expect(audio.dialect, 'asante');
      expect(audio.voice, 'twi-6');
    });

    test('null dialect/voice are allowed', () {
      final audio = TtsAudio(bytes: Uint8List(0), provider: 'poto-tts');
      expect(audio.provider, 'poto-tts');
      expect(audio.dialect, isNull);
      expect(audio.voice, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. AiReply / VoiceReply models
  // ══════════════════════════════════════════════════════════════════════════
  group('AiReply model', () {
    test('parses JSON with all fields', () {
      final reply = AiReply.fromJson({
        'message': 'Hello',
        'language': 'tw',
        'tool_used': 'check_price',
        'data_quality': 'tool_fallback',
        'conversation_id': 'cid-123',
      });
      expect(reply.message, 'Hello');
      expect(reply.language, 'tw');
      expect(reply.toolUsed, 'check_price');
      expect(reply.dataQuality, 'tool_fallback');
      expect(reply.conversationId, 'cid-123');
    });

    test('handles missing optional fields gracefully', () {
      final reply = AiReply.fromJson({'message': 'Hi'});
      expect(reply.message, 'Hi');
      expect(reply.language, isNull);
      expect(reply.toolUsed, isNull);
    });
  });

  group('VoiceReply model', () {
    test('wraps transcript and ai reply', () {
      final reply = VoiceReply(
        transcript: 'Mepe sɛ tomato',
        reply: const AiReply(message: 'Tomato bo yɛ...'),
        conversationId: 'cid-456',
      );
      expect(reply.transcript, 'Mepe sɛ tomato');
      expect(reply.reply.message, 'Tomato bo yɛ...');
      expect(reply.conversationId, 'cid-456');
    });
  });
}

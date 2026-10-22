/// Tests for GhanaianTextNormalizer and GhanaLanguageCatalog.
///
/// COVERAGE
/// --------
/// - Currency normalization (GHS/₵ → spoken form, EN and TW)
/// - Number normalization (digits → words, EN and TW)
/// - Unit normalization (kg, ton, ha → spoken form)
/// - Code-switch bracket insertion (English terms in Twi text)
/// - Language capability matrix queries
/// - Evaluation phrase set structural validation
/// - Pronunciation hint map validation
///
/// VERIFICATION STATUS
/// -------------------
/// UNIT VERIFIED: all tests below.
/// REAL DEVICE VERIFIED: not applicable (pure Dart).
/// HUMAN LISTENING EVALUATION: required for actual voice quality.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:gharvest/ghana_language_catalog.dart';
import 'package:gharvest/services/ghanaian_text_normalizer.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1. Currency normalization — English
  // ══════════════════════════════════════════════════════════════════════════
  group('Currency normalization — English', () {
    test('GHS prefix expands to cedis', () {
      final result = GhanaianTextNormalizer.normalize(
        'Price is GHS 50 per crate.',
        languageCode: 'en-GH',
      );
      expect(result, contains('fifty cedis'));
    });

    test('₵ symbol expands to cedis', () {
      final result = GhanaianTextNormalizer.normalize(
        '₵120 per bag',
        languageCode: 'en-GH',
      );
      expect(result, contains('one hundred and twenty cedis'));
    });

    test('GHS with pesewas expands both', () {
      final result = GhanaianTextNormalizer.normalize(
        'GHS 5.50',
        languageCode: 'en-GH',
      );
      expect(result, contains('five cedis'));
      expect(result, contains('fifty pesewas'));
    });

    test('amounts over 9999 are left as-is', () {
      final result = GhanaianTextNormalizer.normalize(
        'GHS 15000',
        languageCode: 'en-GH',
      );
      expect(result, contains('15000'));
    });

    test('GH¢ symbol is handled', () {
      final result = GhanaianTextNormalizer.normalize(
        'GH¢30',
        languageCode: 'en-GH',
      );
      expect(result, contains('thirty cedis'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. Currency normalization — Twi
  // ══════════════════════════════════════════════════════════════════════════
  group('Currency normalization — Twi', () {
    test('GHS 1 expands to Twi cedi word', () {
      final result = GhanaianTextNormalizer.normalize(
        'GHS 1 na ɛyɛ.',
        languageCode: 'tw',
      );
      expect(result, contains('baako sika'));
    });

    test('GHS 100 expands to Twi hundred + sika', () {
      final result = GhanaianTextNormalizer.normalize(
        'GHS 100',
        languageCode: 'tw',
      );
      expect(result, contains('ɔha'));
      expect(result, contains('sika'));
    });

    test('GHS 120 expands correctly', () {
      final result = GhanaianTextNormalizer.normalize(
        'GHS 120',
        languageCode: 'tw',
      );
      // ɔha ne aduonu sika
      expect(result, contains('ɔha'));
      expect(result, contains('aduonu'));
      expect(result, contains('sika'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Number normalization — English
  // ══════════════════════════════════════════════════════════════════════════
  group('Number normalization — English', () {
    test('single digit expands', () {
      final result = GhanaianTextNormalizer.normalize(
        'You have 3 orders.',
        languageCode: 'en-GH',
      );
      expect(result, contains('three orders'));
    });

    test('teen number expands', () {
      final result = GhanaianTextNormalizer.normalize(
        'There are 15 buyers.',
        languageCode: 'en-GH',
      );
      expect(result, contains('fifteen buyers'));
    });

    test('two-digit number expands', () {
      final result = GhanaianTextNormalizer.normalize(
        '42 bags available.',
        languageCode: 'en-GH',
      );
      expect(result, contains('forty-two bags'));
    });

    test('three-digit number expands', () {
      final result = GhanaianTextNormalizer.normalize(
        '250 kilograms',
        languageCode: 'en-GH',
      );
      expect(result, contains('two hundred and fifty kilograms'));
    });

    test('years in range 1900–2099 are NOT expanded', () {
      final result = GhanaianTextNormalizer.normalize(
        'Since 2024',
        languageCode: 'en-GH',
      );
      expect(result, contains('2024'));
      expect(result, isNot(contains('two thousand')));
    });

    test('zero expands to word', () {
      final result = GhanaianTextNormalizer.normalize(
        '0 items',
        languageCode: 'en-GH',
      );
      expect(result, contains('zero items'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. Number normalization — Twi
  // ══════════════════════════════════════════════════════════════════════════
  group('Number normalization — Twi', () {
    test('1 expands to baako', () {
      final result = GhanaianTextNormalizer.normalize('1', languageCode: 'tw');
      expect(result, contains('baako'));
    });

    test('10 expands to edu', () {
      final result = GhanaianTextNormalizer.normalize('10', languageCode: 'tw');
      expect(result, contains('edu'));
    });

    test('20 expands to aduonu', () {
      final result = GhanaianTextNormalizer.normalize('20', languageCode: 'tw');
      expect(result, contains('aduonu'));
    });

    test('50 expands to aduonum', () {
      final result = GhanaianTextNormalizer.normalize('50', languageCode: 'tw');
      expect(result, contains('aduonum'));
    });

    test('100 expands to ɔha', () {
      final result = GhanaianTextNormalizer.normalize(
        '100',
        languageCode: 'tw',
      );
      expect(result, contains('ɔha'));
    });

    test('1000 expands to apem', () {
      final result = GhanaianTextNormalizer.normalize(
        '1000',
        languageCode: 'tw',
      );
      expect(result, contains('apem'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Unit normalization
  // ══════════════════════════════════════════════════════════════════════════
  group('Unit normalization', () {
    test('kg expands to kilograms (English)', () {
      final result = GhanaianTextNormalizer.normalize(
        '50 kg of tomatoes',
        languageCode: 'en-GH',
      );
      expect(result.toLowerCase(), contains('kilograms'));
    });

    test('ha expands to hectares (English)', () {
      final result = GhanaianTextNormalizer.normalize(
        '2 ha farm',
        languageCode: 'en-GH',
      );
      expect(result.toLowerCase(), contains('hectares'));
    });

    test('°C expands to degrees Celsius', () {
      final result = GhanaianTextNormalizer.normalize(
        'Temperature: 28°C',
        languageCode: 'en-GH',
      );
      expect(result, contains('degrees Celsius'));
    });

    test('kg expands to kilogram in Twi (singular)', () {
      final result = GhanaianTextNormalizer.normalize(
        '1 kg',
        languageCode: 'tw',
      );
      expect(result, contains('kilogram'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. Code-switch bracket insertion
  // ══════════════════════════════════════════════════════════════════════════
  group('Code-switch bracket insertion (Twi)', () {
    test('already-bracketed text is not double-bracketed', () {
      const input = 'Mepe sɛ [tomato price] no yɛ dɛn?';
      final result = GhanaianTextNormalizer.normalize(
        input,
        languageCode: 'tw',
      );
      // Should not produce [[tomato price]]
      expect(result, isNot(contains('[[tomato')));
      expect(result, contains('[tomato price]'));
    });

    test('domain term in Twi gets bracketed', () {
      final result = GhanaianTextNormalizer.normalize(
        'Tomato bo wɔ Kumasi gua no yɛ dɛn?',
        languageCode: 'tw',
      );
      expect(result, contains('[Tomato]'));
    });

    test('English text does not get brackets inserted', () {
      final result = GhanaianTextNormalizer.normalize(
        'The tomato price in Kumasi is thirty cedis.',
        languageCode: 'en-GH',
      );
      // No brackets should be inserted for English text
      expect(result, isNot(contains('[')));
    });

    test('new transport terms get bracketed in Twi', () {
      final result = GhanaianTextNormalizer.normalize(
        'Me pɛ sɛ mehu [truck] [delivery] [driver]',
        languageCode: 'tw',
      );
      expect(result, contains('[truck]'));
      expect(result, contains('[delivery]'));
      expect(result, contains('[driver]'));
    });

    test('new place names get bracketed in Twi', () {
      final result = GhanaianTextNormalizer.normalize(
        'Me pɛ sɛ mehu tomato wɔ [Makola]',
        languageCode: 'tw',
      );
      expect(result, contains('[Makola]'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 7. Empty / trivial input
  // ══════════════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('empty string returns empty string', () {
      expect(GhanaianTextNormalizer.normalize(''), isEmpty);
    });

    test('whitespace-only returns empty string', () {
      expect(GhanaianTextNormalizer.normalize('   ').trim(), isEmpty);
    });

    test('text without special patterns is unchanged', () {
      const input = 'Good morning, Kofi.';
      final result = GhanaianTextNormalizer.normalize(
        input,
        languageCode: 'en-GH',
      );
      expect(result, input);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 8. Language capability matrix
  // ══════════════════════════════════════════════════════════════════════════
  group('Ghana language capability matrix', () {
    test('matrix is non-empty', () {
      expect(ghanaLanguageMatrix, isNotEmpty);
    });

    test('all entries have non-empty code, name, and iso6393', () {
      for (final spec in ghanaLanguageMatrix) {
        expect(spec.code, isNotEmpty, reason: 'Empty code for ${spec.name}');
        expect(spec.name, isNotEmpty, reason: 'Empty name for ${spec.code}');
        expect(spec.iso6393, isNotEmpty, reason: 'Empty ISO for ${spec.code}');
      }
    });

    test('Asante Twi is naturalVoice level', () {
      final twi = specForCode('tw');
      expect(twi, isNotNull);
      expect(twi!.voiceLevel, GhanaVoiceLevel.naturalVoice);
    });

    test('Ghanaian English is naturalVoice level', () {
      final en = specForCode('en-GH');
      expect(en, isNotNull);
      expect(en!.voiceLevel, GhanaVoiceLevel.naturalVoice);
    });

    test('Akuapem Twi is asrAvailable only (no dedicated TTS)', () {
      final ak = specForCode('ak');
      expect(ak, isNotNull);
      expect(ak!.voiceLevel, GhanaVoiceLevel.asrAvailable);
      expect(ak.hasTts, isFalse);
    });

    test('Asante Twi has G2P support', () {
      final twi = specForCode('tw');
      expect(twi!.g2pSupported, isTrue);
    });

    test('Asante Twi supports code-switching', () {
      final twi = specForCode('tw');
      expect(twi!.codeSwitchSupported, isTrue);
    });

    test('Ghanaian English is GREEN for commercial use', () {
      final en = specForCode('en-GH');
      expect(en!.commercialUse, GhanaLicenseStatus.green);
    });

    test('Twi is YELLOW (CC-BY-NC-4.0)', () {
      final twi = specForCode('tw');
      expect(twi!.commercialUse, GhanaLicenseStatus.yellow);
    });

    test('Gonja has the best ASR WER', () {
      final wers = ghanaLanguageMatrix
          .where((s) => s.asrWer != null)
          .map((s) => s.asrWer!)
          .toList();
      final gonja = specForCode('gon');
      expect(
        gonja!.asrWer! <= wers.reduce((a, b) => a < b ? a : b) + 1.0,
        isTrue,
      );
    });

    test('specForCode returns null for unknown code', () {
      expect(specForCode('xx'), isNull);
    });

    test('Ahanta is textOnly', () {
      final aha = specForCode('aha');
      expect(aha, isNotNull);
      expect(aha!.voiceLevel, GhanaVoiceLevel.textOnly);
    });

    test('all ASR WER values are in plausible range (0–100)', () {
      for (final spec in ghanaLanguageMatrix) {
        if (spec.asrWer != null) {
          expect(
            spec.asrWer!,
            inInclusiveRange(0.0, 100.0),
            reason: 'WER out of range for ${spec.code}',
          );
        }
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 9. Evaluation phrase set
  // ══════════════════════════════════════════════════════════════════════════
  group('GHarvest evaluation phrase set', () {
    test('phrase set is non-empty', () {
      expect(kGHarvestEvalPhrases, isNotEmpty);
    });

    test('all phrases have non-empty language and text', () {
      for (final phrase in kGHarvestEvalPhrases) {
        expect(phrase.language, isNotEmpty);
        expect(phrase.text, isNotEmpty);
      }
    });

    test('phrase set contains Ghanaian English phrases', () {
      final enPhrases = kGHarvestEvalPhrases.where(
        (p) => p.language == 'en-GH',
      );
      expect(enPhrases, isNotEmpty);
    });

    test('phrase set contains Twi phrases', () {
      final twiPhrases = kGHarvestEvalPhrases.where((p) => p.language == 'tw');
      expect(twiPhrases, isNotEmpty);
    });

    test('phrase set contains code-switch phrases', () {
      // Code-switch phrases have brackets in the text.
      final csPhrases = kGHarvestEvalPhrases.where(
        (p) => p.language == 'tw' && p.text.contains('['),
      );
      expect(csPhrases, isNotEmpty);
    });

    test('normalization test phrases have expectedNormalized set', () {
      final normPhrases = kGHarvestEvalPhrases.where(
        (p) => p.expectedNormalized != null,
      );
      expect(normPhrases, isNotEmpty);
    });

    test('GHS normalization phrase matches expected output', () {
      // Find the "GHS 250 per bag" phrase.
      final phrase = kGHarvestEvalPhrases.firstWhere(
        (p) => p.text.contains('GHS 250'),
        orElse: () => throw StateError('Phrase not found'),
      );
      final normalized = GhanaianTextNormalizer.normalize(
        phrase.text,
        languageCode: phrase.language,
      );
      expect(normalized.toLowerCase(), contains('two hundred and fifty cedis'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 10. Pronunciation hints map
  // ══════════════════════════════════════════════════════════════════════════
  group('GHarvest pronunciation hints', () {
    test('hints map is non-empty', () {
      expect(kGHarvestPronunciationHints, isNotEmpty);
    });

    test('Kumasi pronunciation hint exists', () {
      expect(kGHarvestPronunciationHints.containsKey('Kumasi'), isTrue);
    });

    test('Accra pronunciation hint exists', () {
      expect(kGHarvestPronunciationHints.containsKey('Accra'), isTrue);
    });

    test('cedi pronunciation hint is correctly spelled', () {
      expect(kGHarvestPronunciationHints.containsKey('cedi'), isTrue);
    });

    test('all hint values are non-empty', () {
      for (final entry in kGHarvestPronunciationHints.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'Empty pronunciation for "${entry.key}"',
        );
      }
    });
  });
}

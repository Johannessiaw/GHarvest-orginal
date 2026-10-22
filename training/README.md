# GHarvest Kofi Ghanaian speech training pack

This directory documents external data and model families that can improve Kofi's Ghanaian speech recognition, language identification, code-switching, and pronunciation. The release does not bundle the large third-party corpora or model weights.

## Recommended source data

| Source | Purpose | Scope | License | GHarvest use |
|---|---|---:|---|---|
| `ghananlpcommunity/ghana-speech` | Ghanaian multilingual ASR | 42 language subsets | CC BY-NC 4.0 | Research/non-commercial unless separately licensed |
| `ghananlpcommunity/ghana-speech-eval` | Held-out evaluation | 65 subsets | CC BY-NC 4.0 | Evaluation only; never train on it |
| `ghananlpcommunity/Ghana_English-Twi_Code-switching_Speech-ipa` | English-Twi code-switch ASR | 54,855 pairs / ~95.6 h | Apache-2.0 (source card) | High-value conversational ASR/code-switch training |
| `ghananlpcommunity/twi-tts-asr` | Twi TTS + ASR | 79,655 / 88.8 h | Verify current card | TTS/ASR experimentation |
| `ghananlpcommunity/navigation-corpus-twi-speech` | Spoken Twi navigation | 52,562 pairs | Verify current card | Navigation voice domain |
| `ghananlpcommunity/ghana-english-asr-2700hrs` | Ghanaian English ASR | ~2,706.8 h | Verify current card | Ghanaian-English ASR adaptation |
| `ghananlpcommunity/ghana-speech-id` | Ghanaian language ID | 41 languages | CC BY-NC 4.0 | Runtime language detection gateway |

## Licensing rule

Do not assume that a public dataset is commercially reusable. Several GhanaNLP sources are CC BY-NC 4.0. Obtain a compatible commercial license or permission before training a production commercial voice model. Keep `ghana-speech-eval` strictly held out for benchmarking.

## Recommended model stack

1. Fast runtime path: a local `ghana-speech-id` service for language ID and a low-latency ASR service.
2. ASR adaptation: Ghanaian English + Twi + KasaSpeech English-Twi code-switching.
3. TTS: a consented Ghanaian speaker set with explicit commercial rights; never clone an identifiable person's voice without permission.
4. Final benchmark: evaluate on `ghana-speech-eval` without training on it.

`prepare_manifest.py` creates a metadata-only manifest. It intentionally does not download third-party audio into the GHarvest release.

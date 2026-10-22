# Kofi Voice Engineering

## Product behavior

Kofi is designed as a voice-first agricultural agent, not a push-to-talk dictation box. A user can start speaking with the default language setting and the backend will try to identify the language from the audio/transcript, preserve the conversation context, execute safe read actions, and answer in short spoken turns.

The loop supports:

- fast speech onset detection;
- adaptive silence detection;
- continuous listen → understand → respond → listen;
- interruption while Kofi is speaking;
- preservation of the beginning of the user's interruption in the same audio recording;
- automatic language switching from the detected voice language;
- deterministic fallback guidance when external AI services are unavailable;
- compact, speech-friendly responses without Markdown formatting;
- Ghanaian English / Twi / code-switch-aware prompts and normalization.

## Current implementation

The current Flutter path is intentionally HTTP-based so it is testable and easy to deploy. It uses an active recorder during Kofi playback for best-effort barge-in. When an interruption is detected, playback stops while the same recorder is promoted into the user's active turn. This avoids discarding the words that caused the interruption.

Ambient noise is calibrated on the first continuous turn and then retained/adapted instead of recalibrating after every Kofi response. This removes a recurring ~1 second dead zone.

Speech-end silence is 650 ms, the audio-settle delay after interruption is 80 ms, and the device TTS rate is tuned above the previous slow default. Backend TTS accepts an explicit speed and includes that speed in its cache key.

## Language detection and Ghanaian speech data

The backend can use an optional `LANGUAGE_ID_URL` service. The recommended service is a local gateway around `ghananlpcommunity/ghana-speech-id`, a model described by Ghana NLP Community as a language-identification system for 41 Ghanaian and West African languages. The model is ASR-backed and therefore should be treated as a supporting signal, not an infallible classifier.

Recommended data sources are documented in `training/README.md`. The release intentionally does not bundle large third-party audio corpora or weights. Several GhanaNLP datasets are CC BY-NC 4.0, so commercial use requires a compatible licence or separate permission. The `ghana-speech-eval` corpus is held out for evaluation and must not be used for training.

## Realtime upgrade

OpenAI's current Realtime API supports server VAD and Semantic VAD. Semantic VAD can wait longer when speech is trailing off and supports more natural turn-taking; Realtime interruption events can cancel a response while the user begins another turn. This is the architectural target for truly full-duplex, low-latency Kofi.

The present release does not claim to be a WebRTC/Reatime implementation. It is a hardened HTTP voice loop with client-side barge-in preservation.

## Commercial voice safety

Do not clone an identifiable speaker without explicit voice consent. Do not assume that a publicly downloadable Ghanaian TTS model is commercially licensed. Review every model card and dataset licence before putting it into a commercial deployment.

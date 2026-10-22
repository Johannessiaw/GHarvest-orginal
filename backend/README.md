# GHarvest Kofi backend

FastAPI service for Kofi voice, text, marketplace tools, logistics discovery, weather, payments and photo-assisted crop guidance.

## Voice path

`POST /api/v1/ai/voice` accepts an audio turn, performs ASR, detects a likely Ghanaian language, continues the user's conversation, executes matching GHarvest tools, and returns a compact spoken response.

For automatic language detection with a GhanaNLP-backed local service, configure:

```text
LANGUAGE_ID_URL=http://127.0.0.1:8001/detect
LANGUAGE_ID_MODEL=ghananlpcommunity/ghana-speech-id
```

For local ASR/TTS, configure `LOCAL_ASR_URL` / `LOCAL_TTS_URL`. Keep all provider credentials server-side.

## Production rules

- `DEMO_MODE=false` for production.
- Never ship `.env` or API keys inside Flutter.
- Treat CC BY-NC datasets as non-commercial unless separately licensed.
- Keep `ghana-speech-eval` out of training.
- Verify payments through the provider/webhook before marking an order paid.
- Verify actual provider status before claiming live prices, weather or logistics.

## Verification from the release environment

The included automated Python suite passes in the release build environment. Flutter/Dart platform execution still requires the Flutter SDK and an actual device/browser audio stack.

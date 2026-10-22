# GHarvest actual app — release contract

This project is the farmer-facing GHarvest application. It is intentionally independent from the Kofi/Voice service project.

## What is real vs standalone

- Marketplace seed catalogue is local demo data when no live marketplace backend is configured.
- Orders created in standalone mode are marked **Payment pending**; the app never claims a payment was verified locally.
- GPS uses the device location service when permission is granted; otherwise the UI explicitly labels the Accra fallback.
- Kofi can connect to the separate VoiceGeo backend with `GHARVEST_AI_BACKEND_URL` and otherwise falls back to deterministic offline help.
- Voice input records audio locally and submits it to `/api/v1/ai/voice` when the VoiceGeo backend is available.

## Recommended connection

Start the VoiceGeo backend, then run the app with:

`flutter run --dart-define=GHARVEST_AI_BACKEND_URL=http://YOUR-PC-LAN-IP:8000`

Android emulator can use `http://10.0.2.2:8000`.

## Design priorities

Fast first paint, local image assets before network images, clear status language, large touch targets, and short Kofi responses for low-literacy users.

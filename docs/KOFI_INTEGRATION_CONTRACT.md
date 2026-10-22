# GHarvest ↔ Kofi Integration Contract

GHarvest is the farmer-facing marketplace, logistics, profile, verification and community application. VoiceGeo/Kofi is the AI/voice service layer.

## Runtime connection

Set `GHARVEST_AI_BACKEND_URL` when running the actual GHarvest app. Example:

- Android emulator: `http://10.0.2.2:8000`
- Windows/desktop with local backend: `http://127.0.0.1:8000`
- Physical phone on LAN: `http://<YOUR-PC-LAN-IP>:8000`

## Responsibilities

GHarvest owns UI, local farmer interactions, marketplace presentation, maps and device permissions.

VoiceGeo owns Kofi conversation state, AI orchestration, speech recognition, speech synthesis, agricultural intent/tool routing and live GHarvest API operations.

## Accuracy rules

Kofi must not invent live market prices, buyer availability, transport availability, delivery status, payment confirmation or weather data. Live facts must come from a connected tool/API. Seed/demo records must be clearly identified as demo/seeded data.

## Offline behavior

The actual GHarvest app remains usable for UI/offline testing. Kofi uses a small deterministic local fallback when the AI backend cannot be reached; that fallback is not presented as a live source of market facts.

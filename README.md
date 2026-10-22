# GHarvest

Farmer-facing Ghana marketplace and logistics app with Kofi voice/AI assistance. This project remains independent from the separate `GHarvest Voice / Kofi` project.

## Core features

Marketplace browsing and selling, cart and order flow, farm/profile verification screens, transport discovery and maps, weather, community/activity tools, local image assets, and a Kofi assistant that can connect to the VoiceGeo backend.

## Connect Kofi

The cleaned package now includes the FastAPI Kofi backend under `backend/`. Run it locally, then launch this app with:

`flutter pub get`

`flutter run --dart-define=GHARVEST_AI_BACKEND_URL=http://YOUR-PC-LAN-IP:8000`

The companion Voice/Kofi project uses the same backend contract. Its documented
command also works with this app:

`flutter run --dart-define=GHarvest_BACKEND_URL=http://YOUR-PC-LAN-IP:8000`

Android emulator: `http://10.0.2.2:8000`.

Without the backend, Kofi falls back to deterministic offline guidance. The app never labels that fallback as live AI data.

## Standalone data policy

The marketplace starts with an initial local catalogue and supports browsing, selling, cart checkout, and durable local order history. Checkout creates an order with **Payment pending** until a payment provider verifies Mobile Money or escrow.

GPS is real when device permission/service is available. Otherwise the transport map explicitly shows that it is using the Accra fallback.

## Staff access

Staff credentials are no longer hard-coded into the source. Configure `GHARVEST_STAFF_ID` and `GHARVEST_STAFF_PASSWORD` with `--dart-define` for local staff testing. Production staff authentication should be supplied by the real GHarvest identity backend.

# WhatsApp Integration (Phase 11, WhatsApp half)

**Status: built (2026-11-04); not yet connected to a real WhatsApp Business number.**

## The non-negotiable rule

A WhatsApp message becomes a **draft**; nothing is saved until someone approves it in the app — no exceptions.

## What exists

- **Official WhatsApp Business Cloud API** (`backend/src/modules/whatsapp/`). Settings → WhatsApp (owner/admin): Phone number ID, business phone, access token and app secret (stored encrypted). The app shows the webhook URL and verify token to enter in Meta's dashboard.
- **Webhook** `POST /whatsapp/webhook`: processed only with a valid `X-Hub-Signature-256` (HMAC-SHA256 of the raw body with the app secret). `GET` answers Meta's verification handshake. Retried deliveries are processed once.
- **Linking:** a member enters their number in Settings → WhatsApp and gets a 6-digit code; sending `LINK 123456` from that phone links it (code hashed, 15 minutes, 5 attempts). Unlinked numbers are told how to link and nothing else happens.
- **Messages:** text from a linked phone → AI draft (same pipeline as the AI Assistant) → reply "Draft created… approve it in the app". `HELP` explains usage. Voice notes and images get a "text only for now" reply.
- **Logs:** every inbound and outbound message with status and error.

## To go live (owner's accounts)

1. A Meta Business account with a WhatsApp Business number and an app (Meta for Developers → WhatsApp).
2. A public HTTPS address for this server (the webhook URL).
3. Enter the details in Settings → WhatsApp, paste the webhook URL and verify token into Meta, subscribe to `messages`.
4. An AI key in Settings → AI assistant (messages are turned into drafts by AI).

## Not yet built

- Voice notes (speech-to-text provider), images/receipts sent through WhatsApp, approving drafts by replying on WhatsApp (approval is in the app by design).

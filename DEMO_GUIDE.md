# DEMO_GUIDE.md — 3-Minute Hackathon Demonstration Script

## Step 1: Open Citizen SOS (`/victim`)
1. Enter freeform emergency description: *"Flood water is rising rapidly. Four people trapped inside. One person is unconscious."*
2. Tap **ANALYZE SITUATION**. Show local rule-based NLP extraction (`FLOOD`, `4 CASUALTIES`, `UNCONSCIOUS`, `PRIORITY: P0 — CRITICAL`).

## Step 2: One-Tap 48-Byte SOS Signal Creation
1. Tap **SEND EMERGENCY SIGNAL**.
2. Show snackbar notification: `48-BYTE SOS CREATED & SAVED LOCALLY!`.
3. Highlight item appearing in local persistent SQLite Outbox.

## Step 3: 50-Node Mesh Simulator (`/mesh-sim`)
1. Open Mesh Simulator. Observe 50 virtual nodes on canvas.
2. Tap **INJECT SOS**. Watch packet hop animation step-by-step across relay nodes to Command Base.
3. Tap **SEVER SECTOR** -> Watch Data Mule custody pickup fallback!

## Step 4: Technical Packet Inspector (`/packet`)
1. Open Packet Inspector. Show 48-byte hex string.
2. Tap **CORRUPT 1 BYTE** -> Show instant transition to `CHECKSUM INVALID — PACKET REJECTED!`.

## Step 5: EOC Command Base (`/command`)
1. Open Command Center. Observe incident pinned on map and prioritized in queue by server score.

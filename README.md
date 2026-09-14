# Aarakshak — Offline-First Emergency Communication Platform

> **THE NETWORK CAN FAIL. THE EMERGENCY SIGNAL SHOULD NOT.**

Aarakshak is a production-quality Flutter application designed for delay-tolerant emergency response during severe disaster blackouts (floods, landslides, structural collapses).

---

## Explicit Subsystem Capabilities
- **REAL**: Flutter App, SQLite Database, SOS Engine, 48-Byte Encoder/Decoder, CRC-16-CCITT, Offline Queue, Triage Engine, Packet Inspector, Command Center UI, Test Suite, FastAPI Server.
- **SIMULATED**: 50-Node Virtual Mesh, Virtual LoRa Radio Model, Data Mule Custody Transfer, Chaos Model.
- **CACHED**: Open-Meteo Weather Data, NASA EONET Environmental Context Data.
- **FUTURE_HARDWARE**: ESP32, SX1262 Physical LoRa Radios, Physical BLE Mesh.

---

## 48-Byte SOS Frame (SOS_FRAME_V1) Specification

```text
Offset  Field              Bytes  Type    Description / Range
────────────────────────────────────────────────────────────────────────────
0x00    MAGIC_BYTE         1      uint8   0x52 ('R')
0x01    PACKET_ID          2      uint16  Monotonic sequence (Big-Endian)
0x03    SOURCE_NODE        4      uint32  Pseudonymous Node ID (Big-Endian)
0x07    HOP_METRICS        1      uint8   High 4-bits TTL (15), Low 4-bits Hops (0)
0x08    TIMESTAMP          4      uint32  Unix timestamp in UTC seconds
0x0C    TRIAGE_PRIORITY    1      uint8   0=P0 Critical, 1=P1 Medical, 2=P2 Needs, 3=P3 Safe
0x0D    LATITUDE           4      int32   Degrees × 10^7 (-90.0 to +90.0)
0x11    LONGITUDE          4      int32   Degrees × 10^7 (-180.0 to +180.0)
0x15    BATTERY_STATUS     1      uint8   0-100%, 255=Unknown
0x16    HEADCOUNT          1      uint8   High 4-bits Adults, Low 4-bits Children
0x17    PAYLOAD_TEXT       23     bytes   UTF-8 encoded string (truncation aware)
0x2E    CRC-16             2      uint16  CRC-16-CCITT over 0x00..0x2D
```

---

## Installation & Running Instructions

### 1. Run Flutter Mobile / Desktop App
```bash
flutter pub get
flutter run -d windows # Or chrome / android
```

### 2. Run Automated Tests
```bash
flutter test
python server/test_vectors_runner.py
```

### 3. Run FastAPI Command Base API
```bash
cd server
pip install -r requirements.txt
uvicorn main:app --reload
```

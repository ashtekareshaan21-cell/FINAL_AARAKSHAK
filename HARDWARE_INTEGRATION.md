# HARDWARE_INTEGRATION.md — Future Hardware Integration Roadmap

## Current Capability Status
- **Physical ESP32**: NOT CURRENTLY AVAILABLE
- **Physical SX1262 LoRa Radio**: NOT CURRENTLY AVAILABLE
- **Physical BLE Mesh**: NOT CURRENTLY TESTED

---

## Hardware Adapter Architecture

```text
       Flutter Application UI
                 │
                 ▼
        TransportAdapter Interface
                 │
  ┌──────────────┴──────────────┐
  ▼                             ▼
[LoRaSimulatorTransport]   [HeltecLoRaHardwareAdapter]
 (Current MVP)              (Future Phase)
                                │
                                ▼
                       Serial / BLE Bridge
                                │
                                ▼
                        Heltec ESP32-SX1262
                                │
                                ▼
                       LoRa 868/915 MHz Air
```

The 48-byte `SOS_FRAME_V1` binary packet and CRC-16 validation logic remain 100% identical when transitioning from simulated radio transports to physical Heltec ESP32 hardware radios.

# ARCHITECTURE.md — ResQMesh AI System Architecture

## Architectural Layers

```text
               PRESENTATION LAYER (Flutter UI)
   Citizen SOS | Command Base | Mesh Sim | Packet Inspector
                          │
                          ▼
            DOMAIN & APPLICATION SERVICES LAYER
   Packet Engine | Triage Engine | Local Signal Extraction
                          │
                          ▼
             DATA & TRANSPORT ADAPTER LAYER
  SQLite Repository | Internet REST | Simulated BLE & LoRa
```

---

## Clean Architecture Principles
1. **Domain Isolation**: Core packet encoding (`SOS_FRAME_V1`), triage scoring algorithms, and CRC-16 checksum validation operate independently of UI widgets and network state.
2. **Offline-First Storage**: All emergency signals are immediately encoded into 48-byte binary frames and persisted in local SQLite tables (`incidents`, `packets`, `packet_events`) before network transmission is attempted.
3. **Transport Agnosticism**: The `TransportAdapter` interface abstracts transmission paths (`InternetTransport`, `SimulatedMeshTransport`, `SimulatedLoRaTransport`).

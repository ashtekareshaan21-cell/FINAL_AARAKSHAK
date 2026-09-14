# API.md — ResQMesh AI FastAPI Server Reference

## Base URL
`http://localhost:8000/api/v1`

---

## Endpoints

### 1. Inject 48-Byte SOS Frame
`POST /telemetry/inject-packet`

#### Request Body
```json
{
  "raw_hex": "52000112345678f066d8e400000b09fe4c2c05a4e85541466c6f6f6420776174657220726973696e67206661737410a5"
}
```

#### Responses
- **201 Created**: CRC valid, packet ingested & server-side priority calculated.
- **400 Bad Request**: Invalid length, invalid magic byte, or CRC-16 checksum failure.
- **409 Conflict**: Duplicate packet (`SOURCE_NODE + PACKET_ID` already ingested).

---

### 2. Fetch Active Incidents
`GET /packets/active`

Returns all ingested incidents ordered by server priority and timestamp.

---

### 3. WebSocket Realtime Telemetry Stream
`ws://localhost:8000/api/v1/ws/stream`

Streams live packet ingestion events and mesh topology updates in real time to connected EOC command dashboards.

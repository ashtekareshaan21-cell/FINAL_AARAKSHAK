# PACKET_PROTOCOL.md — ResQMesh AI SOS_FRAME_V1 Specification

## Protocol Metadata
- **Protocol Version**: `SOS_FRAME_V1`
- **Canonical Frame Size**: Strictly **48 Bytes**
- **Byte Order**: **BIG-ENDIAN** for all multi-byte fields
- **CRC Algorithm**: CRC-16-CCITT (Polynomial `0x1021`, Initial `0xFFFF`, Final XOR `0x0000`, Excludes last 2 bytes)

---

## Field Layout & Bit Offsets

| Offset | Field Name | Size (Bytes) | Data Type | Encoding / Value Range |
|---|---|---|---|---|
| `0x00` | `MAGIC_BYTE` | 1 | `uint8` | `0x52` ('R') |
| `0x01` | `PACKET_ID` | 2 | `uint16` | Monotonic counter (1..65535, Big-Endian) |
| `0x03` | `SOURCE_NODE` | 4 | `uint32` | Pseudonymous 32-bit Node ID |
| `0x07` | `HOP_METRICS` | 1 | `uint8` | High 4 bits: TTL (15..0), Low 4 bits: Hops (0..15) |
| `0x08` | `TIMESTAMP` | 4 | `uint32` | Unix UTC Epoch Seconds |
| `0x0C` | `TRIAGE_PRIORITY` | 1 | `uint8` | `0`=P0 Critical, `1`=P1 Medical, `2`=P2 Needs, `3`=P3 Safe |
| `0x0D` | `LATITUDE` | 4 | `int32` | Signed microdegrees (`Degrees × 10^7`), -90° to +90° |
| `0x11` | `LONGITUDE` | 4 | `int32` | Signed microdegrees (`Degrees × 10^7`), -180° to +180° |
| `0x15` | `BATTERY_STATUS` | 1 | `uint8` | `0..100` = Percentage, `255` = Unknown |
| `0x16` | `HEADCOUNT` | 1 | `uint8` | High 4 bits: Adults (`0..15`), Low 4 bits: Children (`0..15`) |
| `0x17` | `PAYLOAD_TEXT` | 23 | `bytes` | UTF-8 encoded string (truncation aware) |
| `0x2E` | `CRC-16` | 2 | `uint16` | CRC-16-CCITT over bytes `0x00..0x2D` |

---

## Logical Message Identity & Deduplication
Logical identity is defined as:
`SOURCE_NODE + PACKET_ID`

When a relay node forwards a frame, it decrements TTL and increments Hops, then recalculates the CRC-16 checksum. The logical message identity remains unchanged.

---

## Error & Corruption Handling
- If `bytes.length != 48` -> Reject (`INVALID_LENGTH`)
- If `magicByte != 0x52` -> Reject (`INVALID_MAGIC`)
- If `calculateCrc16(bytes) != storedCrc` -> Reject (`INVALID_CRC`)

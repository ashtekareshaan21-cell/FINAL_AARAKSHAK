# MESH_PROTOCOL.md — ResQMesh AI Delay-Tolerant Mesh Protocol

## Network Architecture & Node Types
1. **CITIZEN**: Edge emergency signal generator.
2. **RELAY**: Stationary or mobile intermediate forwarder.
3. **LORA_BRIDGE**: Long-range narrow-band gateway node.
4. **DATA_MULE**: Mobile physical buffer store-and-forward node (e.g. rescue vehicle/drone).
5. **COMMAND**: EOC central base ingested repository.

---

## Store-and-Forward Routing Rules
- **Opportunistic Forwarding**: When a node receives a valid `SOS_FRAME_V1` packet, it validates the CRC-16 checksum and checks its local deduplication cache (`SOURCE_NODE + PACKET_ID`).
- **TTL & Hop Mutation**: If TTL > 0, TTL is decremented by 1, Hop count is incremented by 1, and the CRC-16 checksum is recalculated before relaying.
- **Loop Prevention**: Max TTL is 15. Expired packets (TTL=0) are dropped.

# THREAT_MODEL.md — Security & Integrity Boundaries

## In-Scope Protections (MVP)
- **Accidental Bit Corruption**: Detects wireless channel corruption using CRC-16-CCITT integrity checksums.
- **Malformed Packets**: Rejects frames failing strict 48-byte length or magic byte `0x52` validation.
- **Routing Loops**: Drops packets exceeding maximum TTL hop count (15 hops).
- **Duplicate Flooding**: Suppresses duplicate packet ingestion using `SOURCE_NODE + PACKET_ID` composite keys.

## Out-of-Scope Security (Future Hardware Phase)
- **Cryptographic Authentication**: CRC-16 provides integrity verification, NOT cryptographic signature or identity authentication.
- **Malicious Packet Forgery**: Future releases will introduce ECC digital signatures and AES-GCM encryption.

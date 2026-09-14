import json
import struct
import sys
from pathlib import Path

def calculate_crc16(data: bytes, length: int = 46) -> int:
    crc = 0xFFFF
    for i in range(length):
        crc ^= (data[i] << 8)
        for _ in range(8):
            if (crc & 0x8000) != 0:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
            else:
                crc = (crc << 1) & 0xFFFF;
    return crc & 0xFFFF

def run_test_vectors():
    json_path = Path(__file__).parent.parent / "protocol" / "test_vectors.json"
    if not json_path.exists():
        print(f"Error: {json_path} not found")
        sys.exit(1)

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    vectors = data["test_vectors"]
    print(f"--- RUNNING PYTHON CROSS-LANGUAGE TEST VECTORS ({len(vectors)} vectors) ---")

    all_passed = True
    for vec in vectors:
        vec_id = vec["id"]
        fields = vec["fields"]
        expected_hex = vec["expected_hex"]

        # Encode Frame (48 Bytes)
        buffer = bytearray(48)

        # 0x00: Magic
        buffer[0] = fields["magic_byte"]
        # 0x01: Packet ID
        struct.pack_into(">H", buffer, 1, fields["packet_id"])
        # 0x03: Source Node
        struct.pack_into(">I", buffer, 3, fields["source_node"])
        # 0x07: Hop Metrics
        hop_byte = ((fields["ttl"] & 0x0F) << 4) | (fields["hops"] & 0x0F)
        buffer[7] = hop_byte
        # 0x08: Timestamp
        struct.pack_into(">I", buffer, 8, fields["timestamp"])
        # 0x0C: Priority
        buffer[12] = fields["triage_priority"]
        # 0x0D: Latitude
        struct.pack_into(">i", buffer, 13, fields["latitude_raw"])
        # 0x11: Longitude
        struct.pack_into(">i", buffer, 17, fields["longitude_raw"])
        # 0x15: Battery
        buffer[21] = fields["battery"]
        # 0x16: Headcount
        headcount_byte = ((fields["adults"] & 0x0F) << 4) | (fields["children"] & 0x0F)
        buffer[22] = headcount_byte

        # 0x17: Payload (23 bytes)
        payload_bytes = fields["payload_text"].encode("utf-8")[:23]
        buffer[23:23 + len(payload_bytes)] = payload_bytes

        # 0x2E: CRC-16
        crc = calculate_crc16(bytes(buffer), 46)
        struct.pack_into(">H", buffer, 46, crc)

        actual_hex = bytes(buffer).hex()

        if actual_hex == expected_hex:
            print(f"[PASS] {vec_id}: {actual_hex}")
        else:
            print(f"[FAIL] {vec_id}:\n  Expected: {expected_hex}\n  Actual:   {actual_hex}")
            all_passed = False

    if all_passed:
        print("ALL PYTHON TEST VECTORS PASSED 100% MATCH!")
    else:
        sys.exit(1)

if __name__ == "__main__":
    run_test_vectors()

import asyncio
import json
import os
import sqlite3
import struct
import time
import unittest

TEST_TOKEN = "test-secret-token-12345"
os.environ["AARAKSHAK_API_TOKEN"] = TEST_TOKEN

import server.main as sm

def create_sample_packet(source_node: int, packet_id: int) -> str:
    buf = bytearray(48)
    buf[0] = 0x52
    struct.pack_into(">H", buf, 1, packet_id)
    struct.pack_into(">I", buf, 3, source_node)
    buf[7] = (15 << 4) | 0
    struct.pack_into(">I", buf, 8, int(time.time()))
    buf[12] = 0
    struct.pack_into(">i", buf, 13, int(19.0760 * 1e7))
    struct.pack_into(">i", buf, 17, int(72.8777 * 1e7))
    buf[21] = 90
    buf[22] = (1 << 4) | 0
    txt = b"Security Test"
    buf[23:23 + len(txt)] = txt
    crc = sm.calculate_crc16(bytes(buf), 46)
    struct.pack_into(">H", buf, 46, crc)
    return bytes(buf).hex()

class MockWebSocket:
    def __init__(self):
        self.sent_messages = []

    async def send_json(self, data):
        self.sent_messages.append(data)

class SecurityAckUnitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sm.API_TOKEN = TEST_TOKEN
        sm.init_db()

    def setUp(self):
        sm.API_TOKEN = TEST_TOKEN
        conn = sqlite3.connect(sm.DB_FILE)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM server_incidents")
        conn.commit()
        conn.close()

        # Track broadcasts
        self.broadcasted_messages = []
        self._orig_broadcast = sm.manager.broadcast

        async def capture_broadcast(msg):
            self.broadcasted_messages.append(msg)

        sm.manager.broadcast = capture_broadcast

    def tearDown(self):
        sm.manager.broadcast = self._orig_broadcast

    def _insert_test_incident(self, source_node: int, packet_id: int):
        inc_id = f"INC-{source_node:08X}-{packet_id:04X}"
        hex_str = create_sample_packet(source_node, packet_id)
        now_ts = int(time.time())

        conn = sqlite3.connect(sm.DB_FILE)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO server_incidents (
                id, source_node, packet_id, ttl, hops, timestamp,
                client_priority, server_priority, latitude, longitude,
                battery, adults, children, payload_text, crc, raw_hex, status, received_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            inc_id, source_node, packet_id, 15, 0, now_ts,
            0, 0, 19.0760, 72.8777,
            90, 1, 0, "Security Test", 0, hex_str, "INGESTED", now_ts
        ))
        conn.commit()
        conn.close()
        return f"ACK-{inc_id}", inc_id

    def _get_status(self, inc_id: str):
        conn = sqlite3.connect(sm.DB_FILE)
        cursor = conn.cursor()
        cursor.execute("SELECT status FROM server_incidents WHERE id = ?", (inc_id,))
        row = cursor.fetchone()
        conn.close()
        return row[0] if row else None

    # Test 1: WebSocket ack with no token -> rejected, status unchanged, no broadcast
    def test_ws_ack_no_token_rejected(self):
        ack_token, inc_id = self._insert_test_incident(0x11111111, 1)
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        ws = MockWebSocket()
        msg_text = json.dumps({
            "action": "ACKNOWLEDGE",
            "ack_token": ack_token,
            "message": "Attempt without auth",
        })

        asyncio.run(sm.process_ws_message(ws, msg_text))

        # Check sender received UNAUTHORIZED error
        self.assertEqual(len(ws.sent_messages), 1)
        err = ws.sent_messages[0]
        self.assertEqual(err.get("event"), "ERROR")
        self.assertEqual(err.get("error", {}).get("code"), "UNAUTHORIZED")

        # Database must NOT be updated
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        # Nothing must be broadcast
        self.assertEqual(len(self.broadcasted_messages), 0)

    # Test 2: WebSocket ack with wrong token -> rejected, status unchanged, no broadcast
    def test_ws_ack_wrong_token_rejected(self):
        ack_token, inc_id = self._insert_test_incident(0x22222222, 2)
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        ws = MockWebSocket()
        msg_text = json.dumps({
            "action": "ACKNOWLEDGE",
            "ack_token": ack_token,
            "auth_token": "wrong-secret-token",
            "message": "Attempt with invalid auth",
        })

        asyncio.run(sm.process_ws_message(ws, msg_text))

        # Check sender received UNAUTHORIZED error
        self.assertEqual(len(ws.sent_messages), 1)
        err = ws.sent_messages[0]
        self.assertEqual(err.get("event"), "ERROR")
        self.assertEqual(err.get("error", {}).get("code"), "UNAUTHORIZED")

        # Database must NOT be updated
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        # Nothing must be broadcast
        self.assertEqual(len(self.broadcasted_messages), 0)

    # Test 3: WebSocket ack with correct token -> accepted, status ACKNOWLEDGED, RESPONDER_ACK broadcast
    def test_ws_ack_correct_token_accepted(self):
        ack_token, inc_id = self._insert_test_incident(0x33333333, 3)
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        ws = MockWebSocket()
        msg_text = json.dumps({
            "action": "ACKNOWLEDGE",
            "ack_token": ack_token,
            "auth_token": TEST_TOKEN,
            "message": "Dispatched Rescue Boat 4",
        })

        asyncio.run(sm.process_ws_message(ws, msg_text))

        # Check sender did not receive an error
        self.assertEqual(len(ws.sent_messages), 0)

        # Database MUST be updated to ACKNOWLEDGED
        self.assertEqual(self._get_status(inc_id), "ACKNOWLEDGED")

        # RESPONDER_ACK broadcast MUST be sent to connected clients
        self.assertEqual(len(self.broadcasted_messages), 1)
        b_msg = self.broadcasted_messages[0]
        self.assertEqual(b_msg.get("event"), "RESPONDER_ACK")
        self.assertEqual(b_msg.get("incident_id"), inc_id)
        self.assertEqual(b_msg.get("ack_token"), ack_token)
        self.assertEqual(b_msg.get("message"), "Dispatched Rescue Boat 4")

    # Test 4: HTTP ack behaviour unchanged (still Bearer-protected, still works with correct token)
    def test_http_ack_behaviour_unchanged(self):
        ack_token, inc_id = self._insert_test_incident(0x44444444, 4)
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        # Missing token raises 401
        with self.assertRaises(sm.HTTPException) as ctx_missing:
            sm.require_token(None)
        self.assertEqual(ctx_missing.exception.status_code, 401)
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        # Wrong token raises 401
        with self.assertRaises(sm.HTTPException) as ctx_wrong:
            sm.require_token("Bearer wrong-token")
        self.assertEqual(ctx_wrong.exception.status_code, 401)
        self.assertEqual(self._get_status(inc_id), "INGESTED")

        # Correct token succeeds
        sm.require_token(f"Bearer {TEST_TOKEN}")

        # Calling handle_explicit_ack directly simulates valid HTTP route execution
        req = sm.AckRequest(ack_token=ack_token, message="EOC Dispatch Confirmed")
        result = asyncio.run(sm.handle_explicit_ack(req.ack_token, req.message))
        self.assertIsNotNone(result)
        self.assertEqual(self._get_status(inc_id), "ACKNOWLEDGED")
        self.assertEqual(len(self.broadcasted_messages), 1)
        self.assertEqual(self.broadcasted_messages[0]["event"], "RESPONDER_ACK")

    # Test 5: Server fails closed if AARAKSHAK_API_TOKEN is unset on server
    def test_ws_ack_fails_closed_when_server_token_unset(self):
        ack_token, inc_id = self._insert_test_incident(0x55555555, 5)
        original_token = sm.API_TOKEN
        try:
            sm.API_TOKEN = ""
            # validate_ws_auth must fail closed
            self.assertFalse(sm.validate_ws_auth(None))
            self.assertFalse(sm.validate_ws_auth("any-token"))
            self.assertFalse(sm.validate_ws_auth(TEST_TOKEN))

            ws = MockWebSocket()
            msg_text = json.dumps({
                "action": "ACKNOWLEDGE",
                "ack_token": ack_token,
                "auth_token": TEST_TOKEN,
                "message": "Attempt when server token is unset",
            })
            asyncio.run(sm.process_ws_message(ws, msg_text))

            # Must reject with UNAUTHORIZED
            self.assertEqual(len(ws.sent_messages), 1)
            err = ws.sent_messages[0]
            self.assertEqual(err.get("event"), "ERROR")
            self.assertEqual(err.get("error", {}).get("code"), "UNAUTHORIZED")

            # Status unchanged, no broadcast
            self.assertEqual(self._get_status(inc_id), "INGESTED")
            self.assertEqual(len(self.broadcasted_messages), 0)
        finally:
            sm.API_TOKEN = original_token

if __name__ == "__main__":
    unittest.main()

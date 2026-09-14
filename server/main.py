import struct
import json
import sqlite3
import time
from typing import List, Optional
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(
    title="Aarakshak Command Center API",
    version="1.0.0-PROTOTYPE",
    description="Emergency Telemetry & DTN Packet Ingestion Server"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# SQLite Database setup
DB_FILE = "server_incidents.db"

def init_db():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS server_incidents (
            id TEXT PRIMARY KEY,
            source_node INTEGER NOT NULL,
            packet_id INTEGER NOT NULL,
            ttl INTEGER NOT NULL,
            hops INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            client_priority INTEGER NOT NULL,
            server_priority INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            battery INTEGER NOT NULL,
            adults INTEGER NOT NULL,
            children INTEGER NOT NULL,
            payload_text TEXT NOT NULL,
            crc INTEGER NOT NULL,
            raw_hex TEXT NOT NULL,
            status TEXT NOT NULL,
            received_at INTEGER NOT NULL,
            UNIQUE(source_node, packet_id)
        )
    """)
    conn.commit()
    conn.close()

init_db()

# CRC-16-CCITT implementation in Python
def calculate_crc16(data: bytes, length: int = 46) -> int:
    crc = 0xFFFF
    for i in range(length):
        crc ^= (data[i] << 8)
        for _ in range(8):
            if (crc & 0x8000) != 0:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc & 0xFFFF

class PacketInjectRequest(BaseModel):
    raw_hex: str = Field(..., description="48-byte hex string (96 hex characters)")

class PacketResponse(BaseModel):
    status: str
    message: str
    packet_id: int
    source_node: int
    client_priority: str
    server_priority: str
    crc_valid: bool
    ack_token: str

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                pass

manager = ConnectionManager()

@app.post("/api/v1/telemetry/inject-packet", response_model=PacketResponse, status_code=201)
async def inject_packet(req: PacketInjectRequest):
    hex_str = req.raw_hex.replace(" ", "").replace("\n", "")
    if len(hex_str) != 96:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "INVALID_LENGTH", "message": f"Hex length must be 96 chars (48 bytes), got {len(hex_str)}"}}
        )

    packet_bytes = bytes.fromhex(hex_str)
    magic = packet_bytes[0]
    if magic != 0x52:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "INVALID_MAGIC", "message": f"Invalid magic byte 0x{magic:02x}, expected 0x52"}}
        )

    # Validate CRC-16
    stored_crc = struct.unpack(">H", packet_bytes[46:48])[0]
    calculated_crc = calculate_crc16(packet_bytes, 46)
    if stored_crc != calculated_crc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "INVALID_CRC", "message": f"CRC-16 validation failed (Expected 0x{calculated_crc:04X}, Got 0x{stored_crc:04X})"}}
        )

    # Decode Fields
    packet_id = struct.unpack(">H", packet_bytes[1:3])[0]
    source_node = struct.unpack(">I", packet_bytes[3:7])[0]
    hop_metrics = packet_bytes[7]
    ttl = (hop_metrics >> 4) & 0x0F
    hops = hop_metrics & 0x0F
    ts = struct.unpack(">I", packet_bytes[8:12])[0]
    client_prio_idx = packet_bytes[12]
    lat_raw = struct.unpack(">i", packet_bytes[13:17])[0]
    lon_raw = struct.unpack(">i", packet_bytes[17:21])[0]
    battery = packet_bytes[21]
    headcount = packet_bytes[22]
    adults = (headcount >> 4) & 0x0F
    children = headcount & 0x0F

    payload_bytes = packet_bytes[23:46]
    null_idx = payload_bytes.find(b'\x00')
    if null_idx != -1:
        payload_bytes = payload_bytes[:null_idx]
    payload_text = payload_bytes.decode("utf-8", errors="ignore")

    lat = lat_raw / 1e7
    lon = lon_raw / 1e7

    # Recalculate Server Priority (Server-side decision support)
    server_prio_idx = client_prio_idx
    if "unconscious" in payload_text.lower() or adults + children >= 4:
        server_prio_idx = 0 # P0 Critical override

    priority_labels = ["P0_CRITICAL", "P1_MEDICAL", "P2_NEEDS", "P3_SAFE"]
    client_prio_str = priority_labels[min(client_prio_idx, 3)]
    server_prio_str = priority_labels[min(server_prio_idx, 3)]

    incident_id = f"INC-{source_node:08X}-{packet_id:04X}"
    now_ts = int(time.time())

    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO server_incidents (
                id, source_node, packet_id, ttl, hops, timestamp,
                client_priority, server_priority, latitude, longitude,
                battery, adults, children, payload_text, crc, raw_hex, status, received_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            incident_id, source_node, packet_id, ttl, hops, ts,
            client_prio_idx, server_prio_idx, lat, lon,
            battery, adults, children, payload_text, stored_crc, hex_str, "ACKNOWLEDGED", now_ts
        ))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "DUPLICATE_PACKET", "message": f"Duplicate packet key {source_node}:{packet_id} already ingested"}}
        )
    conn.close()

    # Broadcast WebSocket update
    event_data = {
        "event": "NEW_INCIDENT",
        "id": incident_id,
        "source_node": source_node,
        "packet_id": packet_id,
        "server_priority": server_prio_str,
        "payload": payload_text,
        "latitude": lat,
        "longitude": lon,
    }
    await manager.broadcast(event_data)

    return PacketResponse(
        status="SUCCESS",
        message="Packet validated and ingested into Command Base",
        packet_id=packet_id,
        source_node=source_node,
        client_priority=client_prio_str,
        server_priority=server_prio_str,
        crc_valid=True,
        ack_token=f"ACK-{incident_id}"
    )

@app.get("/api/v1/packets/active")
def get_active_packets():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM server_incidents ORDER BY server_priority ASC, received_at DESC")
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]

@app.websocket("/api/v1/ws/stream")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

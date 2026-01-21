"""
Simple WebSocket Server for Testing Shift Offers
This is a minimal backend example for testing the shift offer system.

Requirements:
    pip install fastapi uvicorn websockets

Run:
    python test_shift_server.py

Then in Flutter app, set:
    wsUrl = 'ws://localhost:3000/ws'
    apiUrl = 'http://localhost:3000/api'
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict
import asyncio
import json
from datetime import datetime

app = FastAPI(title="Shift Offer Test Server")

# Enable CORS for API testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store active WebSocket connections {emp_id: WebSocket}
connections: Dict[int, WebSocket] = {}

# Store pending offers for offline recovery {emp_id: [offers]}
pending_offers: Dict[int, list] = {}


class ShiftResponse(BaseModel):
    emp_id: int
    shift_id: int
    response: str  # "accepted" or "rejected"
    timestamp: str = None


@app.get("/")
async def root():
    return {
        "service": "Shift Offer Test Server",
        "status": "running",
        "active_connections": len(connections),
        "endpoints": {
            "websocket": "ws://localhost:3000/ws/{emp_id}",
            "respond": "POST /api/shift_offer/respond",
            "pending": "GET /api/shift_offers/pending/{emp_id}",
            "send_test": "POST /api/test/send_offer/{emp_id}"
        }
    }


@app.websocket("/ws/{emp_id}")
async def websocket_endpoint(websocket: WebSocket, emp_id: int):
    """WebSocket endpoint for real-time shift offers"""
    await websocket.accept()
    connections[emp_id] = websocket
    print(f"✅ Employee {emp_id} connected. Total connections: {len(connections)}")
    
    try:
        # Send any pending offers
        if emp_id in pending_offers and pending_offers[emp_id]:
            for offer in pending_offers[emp_id]:
                await websocket.send_json(offer)
                print(f"📨 Sent pending offer to employee {emp_id}")
            pending_offers[emp_id] = []  # Clear pending
        
        # Keep connection alive and handle incoming messages
        while True:
            data = await websocket.receive_json()
            
            # Handle pong for keep-alive
            if data.get('type') == 'pong':
                print(f"💓 Pong from employee {emp_id}")
                continue
                
            print(f"📨 Received from {emp_id}: {data}")
            
    except WebSocketDisconnect:
        if emp_id in connections:
            del connections[emp_id]
        print(f"👋 Employee {emp_id} disconnected. Total connections: {len(connections)}")


@app.post("/api/shift_offer/respond")
async def respond_to_shift(response: ShiftResponse):
    """Handle employee response to shift offer"""
    print(f"📥 Shift response: Employee {response.emp_id} {response.response} shift {response.shift_id}")
    
    # In real app, update database here
    return {
        "success": True,
        "assigned": response.response == "accepted",
        "message": f"Shift {response.shift_id} {response.response} by employee {response.emp_id}",
        "timestamp": datetime.now().isoformat()
    }


@app.get("/api/shift_offers/pending/{emp_id}")
async def get_pending_offers(emp_id: int):
    """Get pending offers for offline recovery"""
    offers = pending_offers.get(emp_id, [])
    print(f"📋 Fetching {len(offers)} pending offers for employee {emp_id}")
    return offers


@app.post("/api/test/send_offer/{emp_id}")
async def send_test_offer(emp_id: int, shift_id: int = 999):
    """
    Test endpoint to send a shift offer to an employee
    
    Example: POST http://localhost:3000/api/test/send_offer/123?shift_id=456
    """
    offer = {
        "type": "shift_offer",
        "shift_id": shift_id,
        "date": "2026-01-20",
        "start_time": "09:00",
        "end_time": "17:00",
        "location_name": "Outreach Center",
        "client_name": "Test Client",
        "service_type": "Home Care",
        "description": "Test shift offer from backend"
    }
    
    # If employee is connected, send immediately
    if emp_id in connections:
        try:
            await connections[emp_id].send_json(offer)
            print(f"✅ Sent test offer {shift_id} to employee {emp_id}")
            return {"status": "sent", "emp_id": emp_id, "shift_id": shift_id}
        except Exception as e:
            print(f"❌ Error sending to {emp_id}: {e}")
            return {"status": "error", "message": str(e)}
    else:
        # Store as pending for later
        if emp_id not in pending_offers:
            pending_offers[emp_id] = []
        pending_offers[emp_id].append(offer)
        print(f"📦 Stored pending offer {shift_id} for employee {emp_id}")
        return {"status": "pending", "emp_id": emp_id, "shift_id": shift_id}


@app.get("/api/connections")
async def get_connections():
    """Debug endpoint to see active connections"""
    return {
        "active_connections": list(connections.keys()),
        "total": len(connections),
        "pending_offers": {emp_id: len(offers) for emp_id, offers in pending_offers.items()}
    }


if __name__ == "__main__":
    import uvicorn
    
    print("""
    ╔═══════════════════════════════════════════════════════╗
    ║   Shift Offer Test Server                            ║
    ╠═══════════════════════════════════════════════════════╣
    ║                                                       ║
    ║  WebSocket: ws://localhost:3000/ws/{emp_id}          ║
    ║  API Base:  http://localhost:3000/api                ║
    ║  Docs:      http://localhost:3000/docs               ║
    ║                                                       ║
    ║  Test Commands:                                       ║
    ║  • Send offer: POST /api/test/send_offer/123         ║
    ║  • View connections: GET /api/connections            ║
    ║  • Test with wscat: wscat -c ws://localhost:3000/ws/123 ║
    ║                                                       ║
    ╚═══════════════════════════════════════════════════════╝
    """)
    
    uvicorn.run(app, host="0.0.0.0", port=3000)

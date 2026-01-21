# 🚀 Real-Time Shift Offers System

## 📋 Overview

This is a **production-grade** real-time system for receiving and responding to shift offers without FCM (Firebase Cloud Messaging). It uses **WebSockets** for instant, bi-directional communication between employees and the backend.

### ✨ Key Features

✅ **Real-time delivery** - Instant shift notifications via WebSocket  
✅ **No FCM required** - Direct WebSocket connection using `emp_id`  
✅ **Accept/Reject UI** - Beautiful dialog with shift details  
✅ **Auto-reconnection** - Exponential backoff reconnection logic  
✅ **Offline recovery** - Fetches pending offers when app opens  
✅ **Connection tracking** - Shows connection status to user  
✅ **First-come-first-served** - Real-time assignment  
✅ **Cross-platform** - Works on iOS, Android, and Web  

---

## 📁 File Structure

```
lib/
├── models/
│   └── shift_offer.dart              # Shift offer data model
├── services/
│   ├── shift_socket_service.dart     # WebSocket core logic
│   ├── shift_api_service.dart        # HTTP API for responses
│   ├── shift_offer_manager.dart      # Coordinator service
│   └── shift_offer_helper.dart       # Helper functions & config
├── widgets/
│   └── shift_offer_dialog.dart       # UI for Accept/Reject
└── pages/
    ├── login_page.dart               # Initializes on login
    └── dashboard_page.dart           # Disposes on logout
```

---

## 🏗️ Architecture

### System Flow

```
1. Employee logs in
   ↓
2. initialize shift  WebSocket opens with emp_id
   ↓
3. WebSocket connects to: wss://YOUR_DOMAIN/ws/{emp_id}
   ↓
4. Backend sends shift offer via WebSocket
   ↓
5. Dialog pops up with shift details
   ↓
6. Employee clicks Accept or Reject
   ↓
7. API call sent to: POST /shift_offer/respond
   ↓
8. Backend assigns shift (first to accept wins)
```

### Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **ShiftSocketService** | WebSocket connection, auto-reconnect, message handling |
| **ShiftApiService** | HTTP API calls for responding to offers |
| **ShiftOfferManager** | Coordinates WebSocket + API + UI |
| **ShiftOfferDialog** | UI for displaying offers |
| **shift_offer_helper.dart** | Configuration and helper functions |

---

## ⚙️ Configuration

### 1. Update Backend URLs

Open `lib/services/shift_offer_helper.dart` and update:

```dart
class ShiftOfferConfig {
  // Production example
  static const String wsUrl = 'wss://your-backend-domain.com/ws';
  static const String apiUrl = 'https://your-backend-domain.com/api';
  
  // Local testing example
  // static const String wsUrl = 'ws://192.168.1.100:8000/ws';
  // static const String apiUrl = 'http://192.168.1.100:8000/api';
}
```

### 2. Testing Locally

For local development:

```dart
static const String wsUrl = 'ws://localhost:8000/ws';
static const String apiUrl = 'http://localhost:8000/api';
```

**Note:** Use `ws://` for local, `wss://` for production (SSL)

---

## 📡 Backend Implementation

### WebSocket Endpoint

The backend must implement a WebSocket endpoint at:

```
ws://your-domain.com/ws/{emp_id}
```

#### Example (Python/FastAPI):

```python
from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict

# Store active connections
connections: Dict[int, WebSocket] = {}

@app.websocket("/ws/{emp_id}")
async def websocket_endpoint(websocket: WebSocket, emp_id: int):
    await websocket.accept()
    connections[emp_id] = websocket
    
    try:
        while True:
            data = await websocket.receive_json()
            
            # Handle ping/pong for keep-alive
            if data.get('type') == 'pong':
                continue
                
    except WebSocketDisconnect:
        del connections[emp_id]
```

#### Sending Shift Offers:

```python
async def send_shift_offer(emp_id: int, shift_data: dict):
    """Send shift offer to specific employee"""
    if emp_id in connections:
        await connections[emp_id].send_json({
            "type": "shift_offer",
            "shift_id": shift_data['id'],
            "date": "2026-01-15",
            "start_time": "09:00",
            "end_time": "17:00",
            "location_name": "Outreach",
            "client_name": "John Doe",
            "service_type": "Home Care",
            "description": "Regular home care visit"
        })
```

### HTTP API Endpoints

#### 1. Respond to Offer

```
POST /shift_offer/respond
Content-Type: application/json

{
  "emp_id": 123,
  "shift_id": 456,
  "response": "accepted",  // or "rejected"
  "timestamp": "2026-01-14T15:30:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "assigned": true,  // false if someone else got it first
  "message": "Shift successfully assigned"
}
```

#### 2. Get Pending Offers (Offline Recovery)

```
GET /shift_offers/pending/{emp_id}
```

**Response:**
```json
[
  {
    "shift_id": 789,
    "date": "2026-01-16",
    "start_time": "10:00",
    "end_time": "14:00",
    "location_name": "85 Neeve",
    "client_name": "Jane Smith",
    "service_type": "Nursing Care",
    "description": "Medication administration"
  }
]
```

---

## 🎯 Usage

### Automatic Initialization

The system automatically initializes when an employee logs in:

```dart
// In login_page.dart - already implemented
await initializeShiftOfferSystem();
```

### Manual Operations

```dart
import 'package:nurse_tracking_app/services/shift_offer_helper.dart';

// Check connection status
if (isShiftOfferSystemConnected()) {
  print('✅ Connected to shift offers');
}

// Manually refresh pending offers
await refreshPendingOffers();

// Get manager instance
final manager = getShiftOfferManager();
if (manager != null) {
  print('Current state: ${manager.connectionState}');
}
```

---

## 🧪 Testing

### 1. Test WebSocket Message

```json
{
  "type": "shift_offer",
  "shift_id": 999,
  "date": "2026-01-20",
  "start_time": "13:00",
  "end_time": "18:00",
  "location_name": "Willow Place",
  "client_name": "Test Client",
  "service_type": "Test Service"
}
```

### 2. Testing Tools

**WebSocket Test Client:**
```bash
# Using wscat
npm install -g wscat
wscat -c ws://localhost:8000/ws/123

# Send test message
> {"type":"shift_offer","shift_id":999,"date":"2026-01-20","start_time":"13:00","end_time":"18:00"}
```

**Python Test Script:**
```python
import asyncio
import websockets
import json

async def test_send_offer():
    uri = "ws://localhost:8000/ws/123"
    async with websockets.connect(uri) as websocket:
        offer = {
            "type": "shift_offer",
            "shift_id": 999,
            "date": "2026-01-20",
            "start_time": "13:00",
            "end_time": "18:00",
            "location_name": "Test Location"
        }
        await websocket.send(json.dumps(offer))
        print("Offer sent!")

asyncio.run(test_send_offer())
```

### 3. Test Offline Recovery

1. Kill backend server
2. Open app (should show disconnected)
3. Restart backend with pending offers
4. App should reconnect and fetch pending offers

---

## 🔧 Troubleshooting

### Connection Issues

**Symptom:** WebSocket won't connect

**Solutions:**
1. Check if backend WebSocket server is running
2. Verify URL in `ShiftOfferConfig`
3. Check firewall/security groups for WebSocket ports
4. For local testing, use `ws://` not `wss://`
5. Check console logs for connection errors

**Debug Logs:**
```
🔌 Connecting to WebSocket: wss://domain.com/ws/123
✅ WebSocket connected successfully
```

### Offers Not Appearing

**Symptom:** Connected but no dialogs appear

**Checklist:**
1. Check backend is sending correct JSON format
2. Verify `type: "shift_offer"` in message
3. Check all required fields are present
4. Look for parsing errors in console

**Debug:**
```dart
// In shift_socket_service.dart, check _handleMessage()
debugPrint('📨 Received message: $data');
```

### Accept/Reject Not Working

**Symptom:** Dialog appears but buttons don't work

**Checklist:**
1. Verify API endpoint URL is correct
2. Check backend is receiving POST requests
3. Look for HTTP errors in console
4. Verify `emp_id` is being sent correctly

**Debug:**
```dart
// In shift_api_service.dart
debugPrint('📤 Responding to shift $shiftId: ${response.name}');
```

### Auto-Reconnect Not Working

**Max attempts reached:**
- Increase `_maxReconnectAttempts` in `shift_socket_service.dart`
- Default: 10 attempts
- After reaching max, user must manually restart app

**Manual reconnect:**
```dart
final manager = getShiftOfferManager();
await manager?.reconnect();
```

---

## 📊 Monitoring & Logs

### Connection State

```dart
enum SocketConnectionState {
  disconnected,  // Not connected
  connecting,    // Attempting connection
  connected,     // Successfully connected
  error,         // Connection error (retrying)
}
```

### Important Logs

| Log | Meaning |
|-----|---------|
| `🔌 Connecting to WebSocket` | Attempting connection |
| `✅ WebSocket connected successfully` | Connected |
| `📨 Received message` | Incoming offer |
| `✅ Shift offer received` | Offer parsed successfully |
| `🔄 Reconnecting in X seconds` | Auto-reconnect triggered |
| `❌ Max reconnection attempts reached` | Give up after 10 tries |
| `📤 Sent message` | Response sent to backend |

---

## 🔒 Security Considerations

### 1. Authentication

Current implementation uses `emp_id` for routing. For production:

```dart
// Add token-based auth to WebSocket
final uri = Uri.parse('$wsUrl/$empId?token=$authToken');
```

Backend should validate token on connection.

### 2. SSL/TLS

**Production:** Always use `wss://` (WebSocket Secure)
**Local:** Use `ws://` for testing only

### 3. Rate Limiting

Implement rate limiting on backend to prevent abuse:
- Max connections per employee
- Max responses per minute
- Connection timeout

---

## 🚀 Deployment Checklist

- [ ] Update `wsUrl` and `apiUrl` in `ShiftOfferConfig`
- [ ] Use `wss://` for production
- [ ] Test WebSocket connectivity from production domain
- [ ] Test Accept/Reject API endpoints
- [ ] Test offline recovery
- [ ] Test auto-reconnection
- [ ] Monitor connection logs
- [ ] Set up backend monitoring
- [ ] Configure firewall for WebSocket traffic
- [ ] Test on different network conditions

---

## 🔄 Future Enhancements

### Possible Improvements

1. **Push Notifications Fallback**
   - Use FCM as backup when WebSocket disconnected
   - Combine both for reliability

2. **Sound/Vibration**
   - Audio alert when offer arrives
   - Vibration on mobile devices

3. **Offer History**
   - View past offers
   - See accepted/rejected shifts

4. **Priority Offers**
   - VIP clients get priority
   - Favorite shifts

5. **Multiple Offers**
   - Queue system for multiple simultaneous offers
   - Batch accept/reject

6. **Analytics**
   - Track offer response times
   - Acceptance rates
   - Connection uptime

---

## 📞 Support

For issues or questions:

1. Check console logs for error messages
2. Verify backend connectivity
3. Test with WebSocket client (wscat)
4. Review this guide's Troubleshooting section

---

## 📜 License

This implementation is part of the Gerri-Assist Nurse Application.

---

**Last Updated:** January 2026  
**Version:** 1.0.0

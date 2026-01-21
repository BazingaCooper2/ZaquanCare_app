# ⚡ Shift Offers - Quick Reference

## 🎯 Quick Start (3 Steps)

### 1. Configure Backend URLs

Edit `lib/services/shift_offer_helper.dart`:

```dart
class ShiftOfferConfig {
  static const String wsUrl = 'wss://YOUR_BACKEND_DOMAIN/ws';
  static const String apiUrl = 'https://YOUR_BACKEND_DOMAIN/api';
}
```

### 2. Backend Requirements

**WebSocket Endpoint:**
```
ws://your-domain.com/ws/{emp_id}
```

**Message Format (Sending Offer to Employee):**
```json
{
  "type": "shift_offer",
  "shift_id": 123,
  "date": "2026-01-20",
  "start_time": "09:00",
  "end_time": "17:00",
  "location_name": "Optional",
  "client_name": "Optional",
  "service_type": "Optional",
  "description": "Optional"
}
```

**Response API:**
```
POST /shift_offer/respond
{
  "emp_id": 123,
  "shift_id": 456,
  "response": "accepted"  // or "rejected"
}
```

**Pending Offers API:**
```
GET /shift_offers/pending/{emp_id}
```

### 3. Test

**Using wscat:**
```bash
npm install -g wscat
wscat -c ws://localhost:8000/ws/123

# Send test offer:
> {"type":"shift_offer","shift_id":999,"date":"2026-01-20","start_time":"09:00","end_time":"17:00"}
```

---

## 📱 How It Works

1. **Login** → System auto-initializes
2. **WebSocket connects** → Using employee ID
3. **Backend sends offer** → JSON message via WebSocket
4. **Dialog appears** → Employee sees offer details
5. **Accept/Reject** → HTTP API call to backend
6. **Logout** → System auto-disposes

---

## 🔍 Key Files

| File | Purpose |
|------|---------|
| `shift_offer_helper.dart` | **⚙️ CONFIG - Edit URLs here** |
| `shift_socket_service.dart` | WebSocket connection logic |
| `shift_api_service.dart` | HTTP API calls |
| `shift_offer_manager.dart` | Coordinator |
| `shift_offer_dialog.dart` | UI dialog |
| `shift_offer.dart` | Data model |

---

## 🐛 Debugging

### Check Connection Status

```dart
import 'package:nurse_tracking_app/services/shift_offer_helper.dart';

if (isShiftOfferSystemConnected()) {
  print('✅ Connected');
} else {
  print('❌ Disconnected');
}
```

### Console Logs

Look for these in console:
- `🔌 Connecting to WebSocket: ...` → Attempting
- `✅ WebSocket connected successfully` → Success
- `📨 Received message: ...` → Incoming offer
- `❌ WebSocket connection error: ...` → Failed

### Common Issues

| Problem | Solution |
|---------|----------|
| Won't connect | Check `wsUrl` in config, verify backend running |
| Connected but no offers | Check JSON format from backend |
| Accept/Reject fails | Check `apiUrl` in config, verify API endpoint |
| Auto-reconnect not working | Normal after 10 failed attempts |

---

## 📊 Connection States

```dart
enum SocketConnectionState {
  disconnected,  // Not connected
  connecting,    // Connecting...
  connected,     // ✅ Ready
  error,         // ❌ Error (auto-retrying)
}
```

---

## 🎨 Customization

### Change Connection Indicators

Edit `shift_offer_manager.dart`, line ~78:

```dart
case SocketConnectionState.connected:
  message = '✅ Connected to shift notification service';
  backgroundColor = Colors.green;
```

### Change Dialog Style

Edit `shift_offer_dialog.dart` to modify:
- Colors
- Text styles
- Button labels
- Layout

### Add Custom Fields

1. Add field to `shift_offer.dart` model
2. Update backend to send field
3. Display in `shift_offer_dialog.dart`

---

## 🚀 Production URLs

### Common Patterns

**Heroku:**
```dart
static const String wsUrl = 'wss://your-app.herokuapp.com/ws';
static const String apiUrl = 'https://your-app.herokuapp.com/api';
```

**AWS:**
```dart
static const String wsUrl = 'wss://api.yourdomain.com/ws';
static const String apiUrl = 'https://api.yourdomain.com/api';
```

**Custom Domain:**
```dart
static const String wsUrl = 'wss://backend.yourdomain.com/ws';
static const String apiUrl = 'https://backend.yourdomain.com/api';
```

**Local Testing:**
```dart
static const String wsUrl = 'ws://localhost:8000/ws';
static const String apiUrl = 'http://localhost:8000/api';
```

---

## 🔄 Manual Operations

```dart
import 'package:nurse_tracking_app/services/shift_offer_helper.dart';

// Refresh pending offers
await refreshPendingOffers();

// Get manager instance
final manager = getShiftOfferManager();

// Manual reconnect
await manager?.reconnect();

// Dispose (logout)
disposeShiftOfferSystem();
```

---

## ✅ Deployment Checklist

- [ ] Update `wsUrl` with production WebSocket URL
- [ ] Update `apiUrl` with production API URL  
- [ ] Use `wss://` for production (not `ws://`)
- [ ] Test WebSocket connection from production
- [ ] Test API endpoints
- [ ] Test auto-reconnect by killing backend
- [ ] Test offline recovery
- [ ] Monitor logs for errors

---

## 📚 Full Documentation

See **SHIFT_OFFERS_GUIDE.md** for:
- Complete architecture details
- Backend implementation examples
- Advanced troubleshooting
- Security best practices
- Future enhancements

---

**Version:** 1.0.0  
**Last Updated:** January 2026

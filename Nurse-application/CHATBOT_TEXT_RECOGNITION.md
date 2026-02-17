# Chatbot Natural Language Recognition

## ✅ Implementation Complete

The chatbot now recognizes typed text messages and automatically performs the appropriate actions. If the message is irrelevant, it responds with: **"Please contact your supervisor for assistance."**

## 📝 Recognized Text Patterns

### 1. **Client Booking Ended Early**
Opens confirmation dialog with signature pad.

**Recognized phrases:**
- "booking ended early"
- "booking early"
- "shift ended early"
- "client ended early"
- "the client booking ended"
- "booking ended"

**Example messages:**
- ✅ "The client booking ended early"
- ✅ "Booking ended early"
- ✅ "My shift ended early"

---

### 2. **Client Not Home**
Opens confirmation dialog with signature pad.

**Recognized phrases:**
- "client not home"
- "client not at home"
- "client wasn't home"
- "client absent"
- "nobody home"
- "nobody was home"

**Example messages:**
- ✅ "Client not home"
- ✅ "The client wasn't home"
- ✅ "Client is absent"
- ✅ "Nobody was home"

---

### 3. **Client Cancelled**
Opens confirmation dialog with signature pad.

**Recognized phrases:**
- "client cancelled"
- "client canceled"
- "client cancel"
- "shift cancelled"
- "appointment cancelled"
- "shift canceled"

**Example messages:**
- ✅ "Client cancelled"
- ✅ "The client canceled the appointment"
- ✅ "Shift was cancelled"

---

### 4. **Sick Leave / Call in Sick**
Sends request to supervisor via email.

**Recognized phrases:**
- "sick"
- "call in sick"
- "feeling unwell"
- "not well"
- "ill"

**Example messages:**
- ✅ "I'm sick"
- ✅ "Need to call in sick"
- ✅ "Feeling unwell"
- ✅ "I'm not well today"

---

### 5. **Emergency Leave**
Sends urgent leave request to supervisor.

**Recognized phrases:**
- "emergency leave"
- "emergency" + "leave"
- "emergency" + "urgent"
- "urgent leave"

**Example messages:**
- ✅ "I need emergency leave"
- ✅ "Emergency - need to take urgent leave"
- ✅ "Urgent family emergency leave"

---

### 6. **Emergency Help / 911**
Shows emergency response message.

**Recognized phrases:**
- "emergency" + "help"
- "emergency" + "911"
- "emergency" + "sos"

**Response:**
"Call 911 or click the SOS button in the dashboard"

**Example messages:**
- ✅ "Emergency help needed"
- ✅ "Emergency 911"
- ✅ "Need emergency assistance"

---

### 7. **Running Late**
Sends lateness notification to supervisor.

**Recognized phrases:**
- "late"
- "running late"
- "delay"
- "delayed"

**Example messages:**
- ✅ "I'm running late"
- ✅ "Going to be late"
- ✅ "Delayed in traffic"

---

### 8. **Shift Change / Reschedule**
Sends shift modification request.

**Recognized phrases:**
- "shift change"
- "reschedule"
- "modify shift"
- "change my shift"

**Example messages:**
- ✅ "Need to change my shift"
- ✅ "Can I reschedule?"
- ✅ "Shift modification request"

---

## 🚫 Irrelevant Messages

If the chatbot cannot determine the intent from the message, it will respond:

**"Please contact your supervisor for assistance."**

**Example irrelevant messages:**
- ❌ "What's the weather?"
- ❌ "How are you?"
- ❌ "Random stuff"
- ❌ "asdfghjkl"

---

## 🎯 How It Works

### Text Input Flow:
1. User types message in chatbot
2. System detects intent using keyword matching
3. Based on intent:
   - **Dialog Required** (booking ended, not home, cancelled) → Opens confirmation dialog
   - **Backend Request** (sick, late, leave) → Sends email to supervisor
   - **Information** (emergency help) → Shows appropriate message
   - **Unknown** → "Please contact your supervisor for assistance."

### Intent Detection Logic:
The system uses **smart pattern matching** that checks for:
- Primary keywords (e.g., "client", "booking", "late")
- Secondary keywords (e.g., "not home", "ended early", "cancelled")
- Combinations of keywords (using AND/OR logic)
- Variations in spelling (e.g., "cancelled" vs "canceled")

---

## 📱 User Experience

### Example Conversation:

**User:** "Client not home"
**Bot:** *[Opens dialog with shift details and signature pad]*

**User:** "I'm sick"
**Bot:** "✅ Request sent to your supervisor."

**User:** "What time is it?"
**Bot:** "Please contact your supervisor for assistance."

---

## 🔧 Pattern Matching Improvements

The updated system now:
- ✅ Handles partial phrases (e.g., "booking ended" matches "booking ended early")
- ✅ Recognizes typos and variations
- ✅ Uses AND logic for multi-keyword intents (more accurate)
- ✅ Prioritizes emergency detection (checked first)
- ✅ Has intelligent fallback for unrecognized input

---

## 🧪 Testing Examples

### Test These Phrases:

| Message | Expected Action |
|---------|----------------|
| "Client cancelled shift" | Opens "Client cancelled" dialog |
| "Nobody was home" | Opens "Client not home" dialog |
| "Shift ended early" | Opens "Client booking ended early" dialog |
| "Feeling sick today" | Sends sick leave request |
| "Running 15 mins late" | Sends lateness notification |
| "Emergency family issue" | Sends emergency leave request |
| "Emergency help" | Shows "Call 911" message |
| "How do I clock in?" | "Please contact your supervisor" |
| "Random message" | "Please contact your supervisor" |

---

## 🎨 Visual Feedback

- **Loading spinner** while processing
- **Dialog animations** for confirmation screens
- **Success messages** after actions
- **Error messages** if something fails

---

## 📊 Database Updates

All recognized actions that involve shift changes:
- Update `shift` table (status, clock_out, notes)
- Create `shift_change_requests` record
- Update `time_logs` table
- Send email notification to supervisor

---

## 💡 Tips for Users

**Be clear and concise:**
- ✅ "Client not home"
- ❌ "So I went to the client's place and they weren't there..."

**Use keywords:**
- Include words like "client", "shift", "sick", "late", "emergency"

**Natural language works:**
- "I'm sick" ✅
- "Client cancelled the appointment" ✅
- "Running late" ✅

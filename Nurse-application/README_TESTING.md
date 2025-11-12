# 🧪 Testing Guide - Nurse Tracking App

## Quick Start: Testing Your App

This guide will help you set up test data and verify all features work correctly.

---

## 📋 Prerequisites

Before testing, ensure you have:
- ✅ Google Directions API enabled
- ✅ Supabase database set up
- ✅ App installed on a real device (not emulator)
- ✅ Location permissions granted

---

## 🗄️ Step 1: Add Test Data

### Option A: Using SQL Script (Recommended)

1. Open **Supabase Dashboard** → SQL Editor
2. Open file: **`TEST_DATA.sql`**
3. Copy ALL SQL statements
4. Run in Supabase SQL Editor
5. Verify data was inserted

**See**: `HOW_TO_INSERT_TEST_DATA.md` for detailed instructions

### Option B: Manual Inserts

See examples in `TEST_DATA.sql` for individual INSERT statements.

---

## 🧪 Step 2: Test Features

### Feature 1: Real-Time Location Tracking

**Location**: Time Tracking page

**What to Test**:
1. Open Time Tracking page
2. Grant location permission if prompted
3. Check console for: `📍 Location updated: [coordinates]`
4. Verify blue dot appears on map
5. Verify map centers on your location
6. Wait 10 seconds - location should update again

**Expected Results**:
- ✅ Map centers on your GPS location
- ✅ Blue dot appears
- ✅ Coordinates update every 10 seconds
- ✅ Console shows permission granted + location updates

---

### Feature 2: Next Patient & Route

**Location**: Time Tracking page

**What to Test**:
1. Ensure you have a scheduled shift for today
2. Open Time Tracking page
3. Look for blue info card: "Next Patient: Robert Smith"
4. Verify route line connects you to patient
5. Tap refresh button to reload
6. Green marker should show patient destination

**Expected Results**:
- ✅ Next patient name displayed
- ✅ Patient address shown
- ✅ Green marker on patient location
- ✅ Blue polyline showing route
- ✅ Route updates when you move

**Required**: 
- Shift with `shift_status = 'scheduled'` OR `'in_progress'`
- Client with valid `patient_location` coordinates

---

### Feature 3: Geofencing Auto Clock-In

**Location**: Time Tracking page

**What to Test**:
1. Travel to one of these locations:
   - Willow Place: `43.538165, -80.311467`
   - 85 Neeve: `43.536884, -80.307129`
   - 87 Neeve: `43.536732, -80.307545`
2. Enter within 50-meter radius
3. Wait for auto clock-in notification
4. Check `time_logs` table for entry
5. Verify blue circles on map (geofence boundaries)

**Expected Results**:
- ✅ Automatic clock-in notification
- ✅ Green background on status bar
- ✅ Entry created in `time_logs` table
- ✅ GPS coordinates saved
- ✅ Current time recorded

---

### Feature 4: Shift Management

**Location**: Shifts page

**What to Test**:
1. Go to Shifts page
2. Verify shifts grouped by status:
   - Scheduled (blue)
   - In Progress (orange)
   - Completed (green)
   - Cancelled (red)
3. Tap "Complete" button on a scheduled shift
4. Verify status updates in database
5. Refresh page - status should update

**Expected Results**:
- ✅ Shifts display correctly
- ✅ Grouped by status
- ✅ All shift details visible
- ✅ Status update works
- ✅ Real-time database sync

---

### Feature 5: Reports from Daily_Shift

**Location**: Reports page

**What to Test**:
1. Go to Reports page
2. Check summary cards:
   - Total hours
   - Monthly hours
   - Overtime hours
   - Completed shifts
3. Verify charts load
4. Check last 7 days bar chart
5. Verify pie chart shows distribution

**Expected Results**:
- ✅ Total hours from `daily_shift` table
- ✅ Charts display correctly
- ✅ Last 7 days graph populated
- ✅ All summaries accurate
- ✅ Real-time data

---

### Feature 6: Manual Clock-Out

**Location**: Time Tracking page

**What to Test**:
1. After auto clock-in (from geofencing)
2. Tap "Clock Out" button
3. Verify notification shows hours worked
4. Check `time_logs` table for completion
5. Verify `total_hours` calculated

**Expected Results**:
- ✅ Clock out button works
- ✅ Hours calculated correctly
- ✅ Database entry updated
- ✅ GPS coordinates saved
- ✅ Success notification

---

## 📊 Data Verification

### Check Database

Run these in Supabase SQL Editor:

```sql
-- 1. Verify employee
SELECT * FROM public.employee WHERE emp_id = 16;

-- 2. Check clients with locations
SELECT client_id, first_name, patient_location 
FROM public.client 
WHERE patient_location IS NOT NULL;

-- 3. Next scheduled shift
SELECT s.*, c.first_name, c.patient_location
FROM public.shift s
LEFT JOIN public.client c ON s.client_id = c.client_id
WHERE s.emp_id = 16 
  AND s.date >= CURRENT_DATE
  AND s.shift_status IN ('scheduled', 'in_progress')
ORDER BY s.date, s.shift_start_time
LIMIT 1;

-- 4. Daily hours summary
SELECT shift_date, daily_hrs 
FROM public.daily_shift 
WHERE emp_id = 16
ORDER BY shift_date DESC
LIMIT 7;

-- 5. Time logs
SELECT clock_in_time, clock_out_time, total_hours
FROM public.time_logs 
WHERE emp_id = 16
ORDER BY clock_in_time DESC
LIMIT 5;
```

---

## 🗺️ Expected Map Display

### What You Should See:

1. **Blue Dot** (center of map)
   - Your current location
   - Moves every 10 seconds

2. **Blue Marker**
   - Custom "Your Location" marker
   - Info window on tap

3. **Green Marker**
   - Patient destination
   - Patient name and address

4. **Red Markers** (3)
   - Willow Place
   - 85 Neeve
   - 87 Neeve

5. **Blue Circles** (3)
   - 50-meter geofence boundaries
   - Where auto clock-in happens

6. **Blue Polyline**
   - Route from your location to patient
   - Updates as you move

---

## 🐛 Troubleshooting

### Map Issues

| Problem | Solution |
|---------|----------|
| Blank/gray map | Check internet connection |
| API key error | Verify API key in AndroidManifest.xml |
| No blue dot | Grant location permission |
| Wrong location | Check GPS enabled, go outdoors |
| No route | Enable Google Directions API |

### Data Issues

| Problem | Solution |
|---------|----------|
| No next patient | Add scheduled shift with client_id |
| No route | Client needs valid patient_location |
| Zero hours | Add data to daily_shift table |
| Old dates | Use CURRENT_DATE in test data |
| Wrong employee | Ensure logged in as employee ID 16 |

### Console Issues

| Problem | Solution |
|---------|----------|
| No logs | Check terminal/filter enabled |
| Permission denied | Grant in device settings |
| Location timeout | Go outdoors, wait 30-60 sec |
| Route errors | Enable Directions API in Google Cloud |

---

## ✅ Testing Checklist

### Setup
- [ ] Test data inserted successfully
- [ ] All tables have data
- [ ] Employee exists with emp_id
- [ ] Clients have valid coordinates
- [ ] Shifts scheduled for today

### Location Features
- [ ] Location permission granted
- [ ] GPS updates every 10 seconds
- [ ] Map centers automatically
- [ ] Blue dot appears
- [ ] Manual re-center works

### Patient & Route
- [ ] Next patient displays
- [ ] Green marker shows destination
- [ ] Route polyline appears
- [ ] Route updates when moving
- [ ] Info window shows address

### Geofencing
- [ ] Travel to assisted living location
- [ ] Auto clock-in triggered
- [ ] Notification appears
- [ ] Database entry created
- [ ] GPS coordinates saved

### Shift Management
- [ ] Shifts display correctly
- [ ] Status updates work
- [ ] Complete button functions
- [ ] Database syncs immediately
- [ ] Grouped by status

### Reports
- [ ] Total hours calculated
- [ ] Monthly hours shown
- [ ] Charts display
- [ ] Last 7 days populated
- [ ] Data from daily_shift table

### Manual Clock-Out
- [ ] Clock out button enabled
- [ ] Hours calculated correctly
- [ ] Database updated
- [ ] Success notification
- [ ] Total_hours field populated

---

## 🎯 Success Criteria

Your app is working correctly if:

1. ✅ Map shows your real-time location
2. ✅ Next patient displays with route
3. ✅ Auto clock-in works at locations
4. ✅ Shifts show correct data
5. ✅ Reports pull from daily_shift
6. ✅ All data saves to Supabase
7. ✅ No crashes or errors
8. ✅ Console logs show success

---

## 📞 Need Help?

### Check These Files:
- `TEST_DATA.sql` - Sample data to insert
- `HOW_TO_INSERT_TEST_DATA.md` - Insertion guide
- `LOCATION_TROUBLESHOOTING.md` - Location issues
- `TERMINAL_ERRORS_EXPLAINED.md` - Error explanations
- `DATABASE_SETUP.md` - Database configuration

### Common Issues:
1. **No data showing** → Check emp_id matches your logged-in user
2. **No route** → Enable Google Directions API
3. **Wrong coordinates** → Verify patient_location format
4. **Map not loading** → Check internet connection
5. **Location not updating** → Grant "Always" location permission

---

## 🚀 Ready to Test!

1. Run test data script in Supabase
2. Open app on real device
3. Login as employee
4. Test each feature
5. Check database for changes

**All features should work perfectly!** 🎉

---

**File**: `TEST_DATA.sql` - All sample data  
**Guide**: `HOW_TO_INSERT_TEST_DATA.md` - How to insert  
**Troubleshooting**: `LOCATION_TROUBLESHOOTING.md` - Issues help  

**Version**: 1.0.0  
**Last Updated**: January 2025


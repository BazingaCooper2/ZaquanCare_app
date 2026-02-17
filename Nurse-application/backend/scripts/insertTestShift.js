const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error("❌ Missing Supabase credentials in .env file");
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function insertTestShift() {
    try {
        // 1. Get the current user's emp_id
        // Check for CLI argument first, else default fallback
        let empId = process.argv[2] ? parseInt(process.argv[2]) : 15;

        // If explicitly 'auto', find first available
        if (process.argv[2] === 'auto') {
            const { data: employees, error: empError } = await supabase
                .from('employee')
                .select('emp_id')
                .limit(1);

            if (employees && employees.length > 0) {
                empId = employees[0].emp_id;
            }
        }

        console.log(`👤 Using Employee ID: ${empId}`);

        // 2. Create a Test Client in India (e.g., Apollo Hospital Chennai)
        // Coords: 13.0630, 80.2559
        // Check if exists first to avoid dupes
        let client;
        const { data: existingClient } = await supabase
            .from('client')
            .select()
            .eq('phone_number', '9999999999')
            .maybeSingle();

        if (existingClient) {
            client = existingClient;
            console.log(`✅ Found existing Test Client: ${client.first_name} ${client.last_name} (ID: ${client.client_id})`);
        } else {
            const { data: newClient, error: clientError } = await supabase
                .from('client')
                .insert({
                    first_name: "Test",
                    last_name: "Client (India)",
                    location: "Apollo Hospital, Chennai",
                    phone_number: "9999999999",
                    patient_location: "13.0630,80.2559", // Approximate coords in Chennai
                    service_type: "Hospital",
                    notes: "Temporary test client for routing",
                    email: "test@test.com"
                })
                .select()
                .single();

            if (clientError) {
                console.error("❌ Failed to create test client:", clientError);
                return;
            }
            client = newClient;
            console.log(`✅ Created Test Client: ${client.first_name} ${client.last_name} (ID: ${client.client_id})`);
        }


        // 3. Create a Shift starting NOW
        const now = new Date();
        const endDate = new Date(now.getTime() + 8 * 60 * 60 * 1000); // +8 hours

        const dateStr = now.toISOString().split('T')[0];

        // Format time as HH:mm
        const formatTime = (date) => {
            return date.toTimeString().substring(0, 5);
        };

        const startTimeStr = formatTime(now);
        const endTimeStr = formatTime(endDate);

        console.log(`🕒 Creating shift for ${dateStr}: ${startTimeStr} - ${endTimeStr}`);

        const { data: shift, error: shiftError } = await supabase
            .from('shift')
            .insert({
                emp_id: empId,
                client_id: client.client_id,
                date: dateStr,
                shift_start_time: startTimeStr,
                shift_end_time: endTimeStr,
                shift_status: "scheduled",
                service_type: "Hospital",
                start_latitude: 13.0630, // Optional: Pre-fill location if needed for testing logs
                start_longitude: 80.2559
            })
            .select()
            .single();

        if (shiftError) {
            console.error("❌ Failed to create test shift:", shiftError);
        } else {
            console.log(`✅ Created Test Shift ID: ${shift.shift_id} for ${dateStr}`);
            console.log("👉 Refresh your Flutter app 'Clock In' page to see the new shift!");
        }

    } catch (err) {
        console.error("Unexpected error:", err);
    }
}

insertTestShift();

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
        // 1. Get the current user's emp_id (You might need to know this or we guess)
        // For now, let's look for any employee to grab an ID, or hardcode if you know it.
        // Assuming you are logged in as an employee, we'll try to find one.

        // CHANGE THIS TO YOUR EMP_ID IF YOU KNOW IT (e.g., from the app logs)
        // If you don't know, we will fetch the first one.
        let empId = 15; // Default fallback, likely your user based on context

        const { data: employees, error: empError } = await supabase
            .from('employee')
            .select('emp_id')
            .limit(1);

        if (employees && employees.length > 0) {
            empId = employees[0].emp_id;
            console.log(`👤 Using Employee ID: ${empId}`);
        }

        // 2. Create a Test Client in India (e.g., Apollo Hospital Chennai)
        // Coords: 13.0630, 80.2559
        const { data: client, error: clientError } = await supabase
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
        console.log(`✅ Created Test Client: ${client.first_name} ${client.last_name} (ID: ${client.client_id})`);

        // 3. Create a Shift for TODAY
        const today = new Date().toISOString().split('T')[0];

        const { data: shift, error: shiftError } = await supabase
            .from('shift')
            .insert({
                emp_id: empId,
                client_id: client.client_id,
                date: today,
                shift_start_time: "08:00",
                shift_end_time: "20:00",
                shift_status: "scheduled",
                service_type: "Hospital"
            })
            .select()
            .single();

        if (shiftError) {
            console.error("❌ Failed to create test shift:", shiftError);
        } else {
            console.log(`✅ Created Test Shift ID: ${shift.shift_id} for ${today}`);
            console.log("👉 Refresh your Flutter app 'Clock In' page to see the route!");
        }

    } catch (err) {
        console.error("Unexpected error:", err);
    }
}

insertTestShift();

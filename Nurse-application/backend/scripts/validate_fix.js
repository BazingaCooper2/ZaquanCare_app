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

async function createValidationShifts() {
    try {
        console.log("🛠️  Setting up Validation Data for ALL Employees...");

        // 1. Get ALL Employees
        const { data: employees } = await supabase.from('employee').select('emp_id');

        if (!employees || employees.length === 0) {
            console.error("❌ No employees found!");
            return;
        }

        console.log(`👥 Found ${employees.length} employees. Creating shifts for everyone.`);

        // 2. Get Client (Default to first found)
        let clientId = 1;
        const { data: clients } = await supabase.from('client').select('client_id').limit(1);
        if (clients && clients.length > 0) {
            clientId = clients[0].client_id;
        }

        // Helper to format time HH:mm
        const formatTime = (date) => date.toTimeString().slice(0, 5);

        for (const emp of employees) {
            const empId = emp.emp_id;
            console.log(`Processing Emp ID: ${empId}...`);

            // 3. Create Shift A: 1 Hour from now (The "Active" Shift)
            const timeA = new Date(Date.now() + 60 * 60 * 1000); // Now + 1h
            const dateStrA = timeA.toISOString().split('T')[0];

            const { data: shiftA, error: errA } = await supabase.from('shift').insert({
                emp_id: empId,
                client_id: clientId,
                date: dateStrA,
                shift_start_time: formatTime(timeA),
                shift_end_time: formatTime(new Date(timeA.getTime() + 4 * 60 * 60 * 1000)),
                shift_status: 'scheduled'
            }).select().single();

            if (errA) {
                console.error(`  ❌ Error creating Shift A for ${empId}:`, errA.message);
            } else {
                console.log(`  ✅ [SHIFT A] Created ID: ${shiftA.shift_id}`);
            }

            // 4. Create Shift B: 4 Hours from now (The "Future" Shift)
            const timeB = new Date(Date.now() + 4 * 60 * 60 * 1000); // Now + 4h
            const dateStrB = timeB.toISOString().split('T')[0];

            const { data: shiftB, error: errB } = await supabase.from('shift').insert({
                emp_id: empId,
                client_id: clientId,
                date: dateStrB,
                shift_start_time: formatTime(timeB),
                shift_end_time: formatTime(new Date(timeB.getTime() + 4 * 60 * 60 * 1000)),
                shift_status: 'scheduled'
            }).select().single();

            if (errB) {
                console.error(`  ❌ Error creating Shift B for ${empId}:`, errB.message);
            }
        }

        console.log("\n✅ Data setup complete for ALL users.");
        console.log("👉 ACTION REQUIRED: Run the SQL script 'FIX_ACTIVE_SHIFT.sql' in Supabase SQL Editor immediately.");

    } catch (e) {
        console.error("Unexpected error:", e);
    }
}

createValidationShifts();

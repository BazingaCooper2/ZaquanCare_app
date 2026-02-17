import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl) throw new Error("SUPABASE_URL missing");
if (!supabaseKey) throw new Error("SUPABASE_SERVICE_ROLE_KEY missing");

const supabase = createClient(supabaseUrl, supabaseKey);

// ------------------------------------------------------------
// 1. Employee + Supervisor Lookup
// ------------------------------------------------------------
export async function getEmployeeDetails(emp_id: number) {
  // 1. Fetch employee
  const { data: emp, error: empErr } = await supabase
    .from("employee")
    .select("emp_id, first_name, last_name, email, supervisor_id")
    .eq("emp_id", emp_id)
    .single();

  if (empErr || !emp) {
    console.error("❌ Employee lookup failed:", empErr);
    return null;
  }

  // 2. Fetch supervisor using supervisor_id
  let supervisor_name = "Supervisor";
  let supervisor_email = "supervisor@nursetracker.app";

  if (emp.supervisor_id) {
    const { data: sup, error: supErr } = await supabase
      .from("supervisors")
      .select("full_name, email")
      .eq("id", emp.supervisor_id)
      .single();

    if (!supErr && sup) {
      supervisor_name = sup.full_name;
      supervisor_email = sup.email;
    } else {
      console.error("❌ Supervisor lookup failed:", supErr);
    }
  } else {
    console.warn("⚠️ Employee has no supervisor_id assigned");
  }

  return {
    emp_id: emp.emp_id,
    full_name: `${emp.first_name} ${emp.last_name}`,
    email: emp.email,
    supervisor_name,
    supervisor_email,
  };
}

// ------------------------------------------------------------
// 2. Insert into shift_change_requests
// ------------------------------------------------------------
export async function createShiftChangeRequest(payload: any) {
  const { data, error } = await supabase
    .from("shift_change_requests")
    .insert([payload])
    .select()
    .single();

  if (error) {
    console.error("❌ Insert shift_change_requests failed:", error);
    return null;
  }

  return data;
}

// ------------------------------------------------------------
// 3. Insert into leaves
// ------------------------------------------------------------
export async function createLeaveRecord(payload: any) {
  const { data, error } = await supabase
    .from("leaves")
    .insert([payload])
    .select()
    .single();

  if (error) {
    console.error("❌ Insert leaves failed:", error);
    return null;
  }

  return data;
}

// ------------------------------------------------------------
// 4. Update shift.status
// ------------------------------------------------------------
export async function updateShiftStatus(emp_id: number, type: string) {
  const today = new Date().toISOString().slice(0, 10);

  let status = "late"; // default fallback for 'late_notification'

  if (type === "call_in_sick" || type === "emergency_leave") {
    status = "on_leave";
  }

  if (type === "partial_shift_change") {
    status = "pending_reschedule";
  }

  const { data, error } = await supabase
    .from("shift")
    .update({ shift_status: status })
    .eq("emp_id", emp_id)
    .eq("date", today);

  if (error) console.error("❌ Shift update error:", error);

  return data;
}

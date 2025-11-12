/// <reference lib="deno.ns" />
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ✅ Load from environment variable names, not literal values
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl) throw new Error("SUPABASE_URL is required");
if (!supabaseKey) throw new Error("SUPABASE_SERVICE_ROLE_KEY is required");

// ✅ Initialize Supabase client
const supabase = createClient(supabaseUrl, supabaseKey);

// ============================================================
// 🔹 1. Fetch employee details + supervisor info
// ============================================================
export async function getEmployeeDetails(emp_id: number) {
  console.log(`Fetching employee details for emp_id: ${emp_id}`);

  const { data, error } = await supabase
    .from("employee")
    .select(`
      emp_id,
      first_name,
      last_name,
      email,
      supervisor_id,
      supervisors(full_name, email)
    `)
    .eq("emp_id", emp_id)
    .single();

  if (error) {
    console.error("❌ getEmployeeDetails error:", error);
    return null;
  }

  if (!data) {
    console.error("❌ No employee data found for emp_id:", emp_id);
    return null;
  }

  // Handle supervisor data - it might be an object or array
  let supervisor: any = null;
  if (data.supervisors) {
    // If it's an array (from join), take the first element
    supervisor = Array.isArray(data.supervisors)
      ? data.supervisors[0]
      : data.supervisors;
  }

  const supervisor_name = supervisor?.full_name ?? "Supervisor";
  const supervisor_email = supervisor?.email ?? "supervisor@nursetracker.app";

  if (!supervisor || !supervisor.email) {
    console.warn(`⚠️ No supervisor email found for emp_id ${emp_id}. Using default: ${supervisor_email}`);
  } else {
    console.log(`✅ Supervisor found: ${supervisor_name} (${supervisor_email})`);
  }

  return {
    emp_id: data.emp_id,
    full_name: `${data.first_name ?? ""} ${data.last_name ?? ""}`.trim(),
    email: data.email,
    supervisor_name,
    supervisor_email,
  };
}

// ============================================================
// 🔹 2. Create shift change or leave request
// ============================================================
export async function createShiftChangeRequest(payload: Record<string, any>) {
  console.log("Creating shift change request:", payload);

  const { data, error } = await supabase
    .from("shift_change_requests")
    .insert([payload])
    .select()
    .single();

  if (error) {
    console.error("❌ createShiftChangeRequest error:", error);
    return null;
  }

  console.log(`✅ Shift change request inserted for emp_id: ${payload.emp_id}`);
  return data;
}

// ============================================================
// 🔹 3. Update shift status for today
// ============================================================
export async function updateShiftStatus(emp_id: number, type: string) {
  console.log(`Updating shift status for emp_id: ${emp_id}, type: ${type}`);

  const today = new Date().toISOString().slice(0, 10);
  const newStatus =
    type === "full_day_leave"
      ? "on_leave"
      : type === "partial_shift_change"
        ? "pending_reschedule"
        : "late";

  const { data, error } = await supabase
    .from("shift")
    .update({ shift_status: newStatus })
    .eq("emp_id", emp_id)
    .eq("date", today);

  if (error) {
    console.error("❌ updateShiftStatus error:", error);
    return null;
  }

  console.log(`✅ Shift status updated to "${newStatus}" for ${today}`);
  return data;
}

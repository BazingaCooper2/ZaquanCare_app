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
  const { data, error } = await supabase
    .from("employee")
    .select(`
      emp_id,
      first_name,
      last_name,
      email,
      supervisors(full_name, email)
    `)
    .eq("emp_id", emp_id)
    .single();

  if (error || !data) {
    console.error("❌ Employee lookup failed:", error);
    return null;
  }

  const supervisor =
    Array.isArray(data.supervisors) ? data.supervisors[0] : data.supervisors;

  return {
    emp_id: data.emp_id,
    full_name: `${data.first_name} ${data.last_name}`,
    email: data.email,
    supervisor_name: supervisor?.full_name ?? "Supervisor",
    supervisor_email: supervisor?.email ?? "supervisor@nursetracker.app",
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
    console.error("❌ Insert failed:", error);
    return null;
  }

  return data;
}

// ------------------------------------------------------------
// 3. Update shift.status
// ------------------------------------------------------------
export async function updateShiftStatus(emp_id: number, type: string) {
  const today = new Date().toISOString().slice(0, 10);

  let status = "late"; // default fallback

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

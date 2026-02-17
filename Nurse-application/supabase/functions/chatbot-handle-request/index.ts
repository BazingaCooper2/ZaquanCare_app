import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { sendEmail } from "./email.ts";
import {
  getEmployeeDetails,
  createShiftChangeRequest,
  updateShiftStatus,
} from "./db.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================================
// MAIN FUNCTION HANDLER
// ============================================================================
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      emp_id,
      message,
      intent_type,
      signature_url,
      start_time,
      end_time,
    } = await req.json();

    // ------------------------------------------------------------------------
    // Validate input
    // ------------------------------------------------------------------------
    if (!emp_id || !intent_type) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: "Missing emp_id or intent_type",
        }),
        { status: 400, headers: corsHeaders },
      );
    }

    console.log(`🧠 Intent received: ${intent_type} from emp_id ${emp_id}`);

    // ------------------------------------------------------------------------
    // Fetch employee + supervisor
    // ------------------------------------------------------------------------
    const emp = await getEmployeeDetails(emp_id);
    if (!emp) {
      return new Response(
        JSON.stringify({ ok: false, error: "Employee not found" }),
        { status: 404, headers: corsHeaders },
      );
    }

    // ------------------------------------------------------------------------
    // Insert request into DB
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Insert request into DB
    // ------------------------------------------------------------------------
    let requestRecord: any;

    // A. Always log to shift_change_requests (for supervisor dashboard queues)
    requestRecord = await createShiftChangeRequest({
      emp_id,
      request_type: intent_type,
      requested_start_time: start_time ?? null,
      requested_end_time: end_time ?? null,
      requested_date: new Date().toISOString().slice(0, 10),
      reason: message,
      signature_url: signature_url ?? null,
    });

    // B. If it's a leave request, ALSO insert into 'leaves' table
    if (intent_type === "call_in_sick" || intent_type === "emergency_leave") {
      const { createLeaveRecord } = await import("./db.ts");
      await createLeaveRecord({
        emp_id,
        leave_type: intent_type,
        leave_reason: message,
        leave_start_date: new Date().toISOString().slice(0, 10),
        leave_end_date: new Date().toISOString().slice(0, 10), // Single day for now
        // If times are provided, use them, otherwise null (full day implied or TBD)
        leave_start_time: start_time ?? null,
        leave_end_time: end_time ?? null,
      });
    }

    // ------------------------------------------------------------------------
    // Update shift status
    // ------------------------------------------------------------------------
    await updateShiftStatus(emp_id, intent_type);

    // ------------------------------------------------------------------------
    // Return final response (email will be sent from Flutter app via SMTP)
    // ------------------------------------------------------------------------
    return new Response(
      JSON.stringify({
        ok: true,
        request_id: requestRecord?.id ?? null,
        supervisor: emp.supervisor_name,
        supervisor_email: emp.supervisor_email,
        employee_name: emp.full_name,
        type: intent_type,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("❌ Server Error:", err);

    return new Response(
      JSON.stringify({
        ok: false,
        error: err?.message ?? "Unknown server error",
      }),
      {
        status: 500,
        headers: corsHeaders,
      },
    );
  }
});

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
    const requestRecord = await createShiftChangeRequest({
      emp_id,
      request_type: intent_type,
      requested_start_time: start_time ?? null,
      requested_end_time: end_time ?? null,
      requested_date: new Date().toISOString().slice(0, 10),
      reason: message,
      signature_url: signature_url ?? null,
    });

    // ------------------------------------------------------------------------
    // Update shift status
    // ------------------------------------------------------------------------
    await updateShiftStatus(emp_id, intent_type);

    // ------------------------------------------------------------------------
    // Build email message
    // ------------------------------------------------------------------------
    let emailBody = "";

    switch (intent_type) {
      case "call_in_sick":
        emailBody =
          `${emp.full_name} is calling in sick.\n\nMessage: ${message}`;
        break;

      case "emergency_leave":
        emailBody =
          `${emp.full_name} has requested EMERGENCY LEAVE.\n\nMessage: ${message}`;
        break;

      case "partial_shift_change":
        emailBody =
          `${emp.full_name} requests a shift change.\nFrom: ${start_time}\nTo: ${end_time}\n\nMessage: ${message}`;
        break;

      case "late_notification":
        emailBody =
          `${emp.full_name} will be late for their shift.\n\nMessage: ${message}`;
        break;

      case "client_booking_ended_early":
        emailBody =
          `${emp.full_name} reports: Client booking ended early.\nStart: ${start_time}\nEnd: ${end_time}\n\nMessage: ${message}`;
        break;

      case "client_not_home":
        emailBody =
          `${emp.full_name} reports: Client not home.\n\nMessage: ${message}`;
        break;

      case "client_cancelled":
        emailBody =
          `${emp.full_name} reports: Client cancelled.\n\nMessage: ${message}`;
        break;

      default:
        emailBody =
          `${emp.full_name} submitted a request.\n\nMessage: ${message}`;
    }

    // ------------------------------------------------------------------------
    // Send email
    // ------------------------------------------------------------------------
    console.log(`📧 Sending email → ${emp.supervisor_email}`);
    const emailSent = await sendEmail(
      emp.supervisor_email,
      "Nurse Shift / Client Update",
      emailBody,
    );

    // ------------------------------------------------------------------------
    // Return final response
    // ------------------------------------------------------------------------
    return new Response(
      JSON.stringify({
        ok: true,
        request_id: requestRecord?.id ?? null,
        email_sent: emailSent.ok,
        supervisor: emp.supervisor_name,
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

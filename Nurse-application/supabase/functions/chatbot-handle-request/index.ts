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

// 🧠 Parse chatbot message → detect intent
function parseMessage(message: string) {
  const msg = message.toLowerCase();

  if (
    msg.includes("leave") ||
    msg.includes("day off") ||
    msg.includes("off today") ||
    msg.includes("take leave")
  ) {
    return { type: "full_day_leave" };
  }

  const hasCancelKeywords =
    msg.includes("cancel") ||
    msg.includes("cannot") ||
    msg.includes("can't") ||
    msg.includes("unable") ||
    msg.includes("cannot do");

  const match = msg.match(
    /from\s+(\d{1,2}\s*(?:am|pm)?(?::\d{2})?)\s+to\s+(\d{1,2}\s*(?:am|pm)?(?::\d{2})?)/i,
  );
  if (match) {
    return { type: "partial_shift_change", start: match[1], end: match[2] };
  }

  if (hasCancelKeywords && (msg.includes("shift") || msg.includes("schedule"))) {
    const timeMatch = msg.match(
      /(\d{1,2}\s*(?:am|pm)?(?::\d{2})?)\s+to\s+(\d{1,2}\s*(?:am|pm)?(?::\d{2})?)/i,
    );
    if (timeMatch) {
      return { type: "partial_shift_change", start: timeMatch[1], end: timeMatch[2] };
    }
    return { type: "partial_shift_change", start: null, end: null };
  }

  if (msg.includes("late") || msg.includes("running late") || msg.includes("be late")) {
    return { type: "late_notification" };
  }

  return { type: "faq" };
}

// 🚀 Main Function
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { emp_id, message } = await req.json();

    if (!emp_id || !message) {
      return new Response(JSON.stringify({ ok: false, error: "Missing emp_id or message" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const intent = parseMessage(message);
    console.log(`🧠 Detected intent: ${intent.type} for emp_id ${emp_id}`);

    if (intent.type === "faq") {
      return new Response(JSON.stringify({ ok: true, type: "faq" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 🧾 Fetch employee + supervisor
    const emp = await getEmployeeDetails(emp_id);
    if (!emp) {
      return new Response(JSON.stringify({ ok: false, error: "Employee not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 🗓 Create DB record
    const reqRecord = await createShiftChangeRequest({
      emp_id: emp.emp_id,
      request_type: intent.type,
      requested_start_time: intent.start || null,
      requested_end_time: intent.end || null,
      requested_date: new Date().toISOString().slice(0, 10),
      reason: message,
    });

    // 🔄 Update shift status
    await updateShiftStatus(emp.emp_id, intent.type);

    // ✉️ Email content
    const subject = `Shift / Leave Request from ${emp.full_name}`;
    let body = "";

    switch (intent.type) {
      case "full_day_leave":
        body = `Employee ${emp.full_name} has requested a full-day leave.\n\nMessage: ${message}`;
        break;
      case "partial_shift_change":
        body = intent.start && intent.end
          ? `Employee ${emp.full_name} requests to cancel/change shift from ${intent.start} to ${intent.end}.\n\nMessage: ${message}`
          : `Employee ${emp.full_name} requests a shift cancellation.\n\nMessage: ${message}`;
        break;
      case "late_notification":
        body = `Employee ${emp.full_name} will be late for their shift.\n\nMessage: ${message}`;
        break;
    }

    console.log(`📧 Sending email to supervisor: ${emp.supervisor_email}`);
    const emailSent = await sendEmail(emp.supervisor_email, subject, body);

    const responsePayload = {
      ok: true,
      request_id: reqRecord?.id ?? null,
      email_sent: emailSent.ok,
      supervisor: emp.supervisor_name,
      type: intent.type,
    };

    console.log("✅ Chatbot request processed successfully.");
    return new Response(JSON.stringify(responsePayload), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("❌ Error in chatbot handler:", err);
    return new Response(JSON.stringify({ ok: false, error: err.message || "Unknown error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

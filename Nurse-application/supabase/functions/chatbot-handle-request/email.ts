/// <reference lib="deno.ns" />

// 📧 email.ts — Clean Resend API version using RESEND_API_KEY

export async function sendEmail(to: string, subject: string, text: string) {
  // 🧩 Fetch Resend API key from environment
  const resendKey = Deno.env.get("RESEND_API_KEY");

  console.log(`📨 Attempting to send email to: ${to}`);
  console.log(`Subject: ${subject}`);

  if (!resendKey) {
    console.warn("⚠️ RESEND_API_KEY not configured in environment.");
    return { ok: false, error: "Missing RESEND_API_KEY" };
  }

  try {
    // 🔹 Send email via Resend API
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        // ✅ Use verified sandbox sender for Resend testing
        from: "supabase@resend.dev",
        to: [to],
        subject,
        html: buildEmailHtml(text),
      }),
    });

    const result = await res.json();

    if (!res.ok || result.error) {
      console.error("❌ Resend API Error:", result.error || result);
      return { ok: false, error: result.error?.message || `HTTP ${res.status}` };
    }

    console.log(`✅ Email sent successfully via Resend. ID: ${result.id}`);
    return { ok: true, result, id: result.id };
  } catch (err) {
    console.error("❌ Email send error:", err);
    return { ok: false, error: err.message };
  }
}

// 🔹 HTML email template
function buildEmailHtml(text: string): string {
  const htmlText = text.replace(/\n/g, "<br>");
  return `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <title>Nurse App Notification</title>
    <style>
      body {
        font-family: system-ui, sans-serif;
        background-color: #f6f6f6;
        margin: 0;
        padding: 20px;
        color: #333;
      }
      .container {
        background: white;
        border-radius: 8px;
        max-width: 600px;
        margin: 0 auto;
        padding: 24px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.1);
      }
      .header {
        background: linear-gradient(135deg, #667eea, #764ba2);
        color: white;
        padding: 16px;
        text-align: center;
        border-radius: 8px 8px 0 0;
      }
      .message-box {
        background: #f8f9fa;
        border-left: 4px solid #667eea;
        padding: 16px;
        margin: 20px 0;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header"><h2>📋 Nurse Shift / Leave Notification</h2></div>
      <p>You have received a new update request:</p>
      <div class="message-box">${htmlText}</div>
      <p>Please review and take appropriate action.</p>
      <p style="font-size: 12px; color: #666;">This is an automated message from the Nurse Tracker App.</p>
    </div>
  </body>
  </html>
  `.trim();
}

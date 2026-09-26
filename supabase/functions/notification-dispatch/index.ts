// notification-dispatch — channel-neutral customer notification gateway.
// Email is enabled now. WhatsApp is deliberately represented as a future
// channel so payment/order events do not need to be rewritten later.
//
// Current channel:
//   email -> Resend
//
// Future channel:
//   whatsapp -> WhatsApp Business API/provider
//
// This function is internal. Callers must authenticate with the Supabase
// service-role key. Customer-facing clients never call it directly.

import { serve } from "https://deno.land/std@0.190.0/http/server.ts";

const cors = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: cors,
  });
}

function esc(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatMoney(value: unknown): string {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat("en-UG", {
    maximumFractionDigits: 0,
  }).format(Number.isFinite(amount) ? amount : 0);
}

function trackingUrl(orderNumber: string): string {
  const base =
    Deno.env.get("NILE_TROPICAL_TRACKING_BASE_URL") ??
    "https://niletropicaluganda.com/app/#/track/";
  return base.replace(/\/$/, "") + "/" + encodeURIComponent(orderNumber);
}

function channelList(value: unknown): string[] {
  if (!Array.isArray(value)) return ["email"];
  return value
    .map((v) => String(v).trim().toLowerCase())
    .filter((v) => ["email", "whatsapp"].includes(v));
}

async function sendEmail(payload: {
  to: string;
  customerName: string;
  orderNumber: string;
  total: unknown;
  paymentMethod: string;
  status: string;
  event: string;
  orderId: string;
}) {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from =
    Deno.env.get("RESEND_FROM_EMAIL") ??
    "Nile Tropical <orders@brianodoch.com>";

  if (!apiKey) {
    return {
      channel: "email",
      status: "not_configured",
      message: "RESEND_API_KEY is not configured",
    };
  }

  const order = esc(payload.orderNumber);
  const name = esc(payload.customerName || "Customer");
  const amount = formatMoney(payload.total);
  const method = esc(payload.paymentMethod || "Mobile Money");
  const status = esc(payload.status || "Processing");
  const link = trackingUrl(payload.orderNumber);
  const event = esc(payload.event);

  const subject =
    payload.event === "payment_confirmed"
      ? `Payment successful — Order ${payload.orderNumber}`
      : `Nile Tropical order update — ${payload.orderNumber}`;

  const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${subject}</title>
</head>
<body style="margin:0;background:#f5f7f8;font-family:Arial,Helvetica,sans-serif;color:#18212b">
  <div style="max-width:640px;margin:0 auto;padding:28px 16px">
    <div style="background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e6eaee">
      <div style="background:#0b6b3a;padding:28px 26px;color:#ffffff">
        <div style="font-size:24px;font-weight:800">Nile Tropical</div>
        <div style="margin-top:6px;font-size:14px;opacity:.9">Fresh products. Simple ordering. Reliable delivery.</div>
      </div>

      <div style="padding:30px 26px">
        <div style="font-size:24px;font-weight:800;margin-bottom:8px">
          ${payload.event === "payment_confirmed" ? "Payment successful" : "Order update"}
        </div>

        <p style="font-size:16px;line-height:1.6;margin:0 0 22px">
          Hello ${name},<br><br>
          ${payload.event === "payment_confirmed"
            ? "We have successfully received your payment for the order below."
            : "There is a new update on your Nile Tropical order."}
        </p>

        <div style="background:#f7faf8;border:1px solid #dfeae3;border-radius:14px;padding:18px">
          <div style="font-size:13px;color:#64717b">ORDER NUMBER</div>
          <div style="font-size:20px;font-weight:800;margin-top:4px">${order}</div>

          <div style="height:14px"></div>

          <div style="font-size:13px;color:#64717b">AMOUNT</div>
          <div style="font-size:20px;font-weight:800;margin-top:4px">UGX ${amount}</div>

          <div style="height:14px"></div>

          <div style="font-size:13px;color:#64717b">PAYMENT</div>
          <div style="font-size:16px;font-weight:700;margin-top:4px">${method}</div>

          <div style="height:14px"></div>

          <div style="font-size:13px;color:#64717b">ORDER STATUS</div>
          <div style="font-size:16px;font-weight:700;margin-top:4px">${status}</div>
        </div>

        <div style="text-align:center;margin:28px 0">
          <a href="${link}"
             style="display:inline-block;background:#0b6b3a;color:#ffffff;text-decoration:none;padding:14px 24px;border-radius:10px;font-weight:800">
            Track My Order
          </a>
        </div>

        <p style="font-size:13px;line-height:1.6;color:#68737d;margin:0">
          If the button does not work, use this tracking link:<br>
          <a href="${link}" style="color:#0b6b3a;word-break:break-all">${link}</a>
        </p>
      </div>

      <div style="padding:18px 26px;background:#fafbfb;color:#7b858d;font-size:12px">
        This is an automated Nile Tropical order notification (${event}).
        Please keep this email for your records.
      </div>
    </div>
  </div>
</body>
</html>`;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": `${payload.event}/${payload.orderId}`,
    },
    body: JSON.stringify({
      from,
      to: [payload.to],
      subject,
      html,
      tags: [
        { name: "application", value: "nile_tropical" },
        { name: "event", value: payload.event },
      ],
    }),
  });

  const bodyText = await response.text();
  let body: unknown;
  try {
    body = JSON.parse(bodyText);
  } catch {
    body = { raw: bodyText };
  }

  if (!response.ok) {
    return {
      channel: "email",
      status: "failed",
      http_status: response.status,
      response: body,
    };
  }

  return {
    channel: "email",
    status: "sent",
    response: body,
  };
}

async function sendWhatsAppFuture(_payload: Record<string, unknown>) {
  // Intentionally not connected yet.
  // When WhatsApp Business is introduced, this function becomes the only
  // channel-specific area that needs a provider implementation.
  return {
    channel: "whatsapp",
    status: "not_configured",
    message: "WhatsApp channel is reserved for future integration",
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: cors });
  }

  if (req.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  try {
    const auth = req.headers.get("authorization") ?? "";
    const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!expected || auth !== `Bearer ${expected}`) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const event = String(body.event ?? "").trim();
    const orderId = String(body.order_id ?? "").trim();
    const orderNumber = String(body.order_number ?? "").trim();
    const customerName = String(body.customer_name ?? "").trim();
    const email = String(body.email ?? "").trim();
    const phone = String(body.phone ?? "").trim();
    const total = body.total ?? 0;
    const paymentMethod = String(body.payment_method ?? "").trim();
    const status = String(body.status ?? "").trim();
    const channels = channelList(body.channels);

    if (!event || !orderId || !orderNumber) {
      return json({
        error: "event, order_id and order_number are required",
      }, 400);
    }

    if (!email && !phone) {
      return json({
        error: "At least one notification destination is required",
      }, 400);
    }

    const results: unknown[] = [];

    for (const channel of channels) {
      if (channel === "email") {
        if (!email) {
          results.push({
            channel: "email",
            status: "skipped",
            message: "Customer email is not available",
          });
          continue;
        }

        results.push(await sendEmail({
          to: email,
          customerName,
          orderNumber,
          total,
          paymentMethod,
          status,
          event,
          orderId,
        }));
      }

      if (channel === "whatsapp") {
        results.push(await sendWhatsAppFuture({
          event,
          order_id: orderId,
          order_number: orderNumber,
          customer_name: customerName,
          phone,
          total,
          payment_method: paymentMethod,
          status,
          tracking_url: trackingUrl(orderNumber),
        }));
      }
    }

    return json({
      ok: true,
      event,
      order_id: orderId,
      order_number: orderNumber,
      results,
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

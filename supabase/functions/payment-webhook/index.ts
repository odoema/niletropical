import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type,x-reference-id,x-callback-url",
  "Access-Control-Allow-Methods": "POST,PUT,OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const url = Deno.env.get("SUPABASE_URL");
const serviceKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY");

const gatewayBase = (Deno.env.get("MTN_GATEWAY_BASE_URL") ??
  "https://132.145.240.116").replace(/\/$/, "");
const gatewaySecret =
  Deno.env.get("MTN_GATEWAY_SHARED_SECRET") ??
  Deno.env.get("NILE_MTN_GATEWAY_SECRET") ??
  Deno.env.get("GATEWAY_SHARED_SECRET");

if (!url || !serviceKey) {
  console.error("[payment-webhook] Supabase server configuration is incomplete");
}

const admin = url && serviceKey ? createClient(url, serviceKey) : null;

async function gatewayGet(path: string) {
  if (!gatewaySecret) throw new Error("MTN_GATEWAY_NOT_CONFIGURED");
  const response = await fetch(gatewayBase + path, {
    headers: { "X-Gateway-Secret": gatewaySecret },
  });
  const raw = await response.text();
  let body: unknown = raw;
  try {
    body = JSON.parse(raw);
  } catch (_) {
    // Preserve non-JSON gateway responses for diagnostics.
  }
  return { status: response.status, body };
}

function fail(message: string, status = 500) {
  return json({ error: message }, status);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST" && req.method !== "PUT") {
    return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  }
  if (!admin) return fail("SERVER_NOT_CONFIGURED");

  const raw = await req.text();
  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw || "{}") as Record<string, unknown>;
  } catch (_) {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const referenceId = String(
    body.referenceId ??
      body.reference_id ??
      body.requestId ??
      req.headers.get("x-reference-id") ??
      "",
  ).trim();

  if (!referenceId) return json({ error: "REFERENCE_REQUIRED" }, 400);

  const eventId = referenceId.slice(0, 255);
  const eventType = String(
    body.eventType ?? body.event_type ?? body.status ?? "callback",
  ).slice(0, 120);

  const { data: existing, error: existingError } = await admin
    .from("payment_webhook_events")
    .select("id,processed")
    .eq("provider", "mtn_uganda")
    .eq("event_id", eventId)
    .maybeSingle();

  if (existingError) return fail("WEBHOOK_EVENT_LOOKUP_FAILED");

  if (existing) {
    return json({
      ok: true,
      duplicate: true,
      processed: existing.processed,
    });
  }

  const { error: eventError } = await admin
    .from("payment_webhook_events")
    .insert({
      provider: "mtn_uganda",
      event_id: eventId,
      event_type: eventType,
      payload: body,
      // MTN callback signature verification is not implemented because the
      // currently configured callback contract does not expose a verifiable
      // signature in the live integration. Payment confirmation therefore
      // requires an independent gateway status check below.
      signature_valid: false,
      processed: false,
    });

  if (eventError) {
    // A concurrent callback may have inserted the same unique event.
    const { data: concurrent } = await admin
      .from("payment_webhook_events")
      .select("id,processed")
      .eq("provider", "mtn_uganda")
      .eq("event_id", eventId)
      .maybeSingle();

    if (concurrent) {
      return json({
        ok: true,
        duplicate: true,
        processed: concurrent.processed,
      });
    }
    return fail("WEBHOOK_EVENT_STORE_FAILED");
  }

  const { data: tx, error: txError } = await admin
    .from("payment_transactions")
    .select("id,order_id,provider_reference,amount,currency,status")
    // payment-initiate records the local transaction under the canonical
    // gateway provider identifier. The callback event itself remains
    // mtn_uganda in payment_webhook_events because that identifies the
    // upstream callback source.
    .eq("provider", "mtn_gateway")
    .eq("provider_reference", referenceId)
    .maybeSingle();

  if (txError) return fail("TRANSACTION_LOOKUP_FAILED");
  if (!tx) {
    return json({
      ok: true,
      processed: false,
      reason: "TRANSACTION_NOT_FOUND",
    });
  }

  const callbackAmount = body.amount ?? body.transactionAmount;
  if (
    callbackAmount !== undefined &&
    Number(callbackAmount) !== Number(tx.amount)
  ) {
    return json(
      { ok: false, processed: false, reason: "AMOUNT_MISMATCH" },
      409,
    );
  }

  const callbackCurrency = body.currency ?? body.transactionCurrency;
  if (
    callbackCurrency !== undefined &&
    String(callbackCurrency) !== String(tx.currency)
  ) {
    return json(
      { ok: false, processed: false, reason: "CURRENCY_MISMATCH" },
      409,
    );
  }

  let verified;
  try {
    verified = await gatewayGet(
      "/mtn/collection/request-to-pay/" +
        encodeURIComponent(referenceId),
    );
  } catch (_) {
    return json(
      {
        ok: true,
        processed: false,
        reason: "STATUS_RECONCILIATION_UNAVAILABLE",
      },
      202,
    );
  }

  if (verified.status !== 200) {
    return json(
      {
        ok: true,
        processed: false,
        reason: "MTN_STATUS_NOT_AVAILABLE",
      },
      202,
    );
  }

  const gatewayPayload =
    (verified.body as Record<string, unknown> | null)?.body ??
    verified.body ??
    {};
  const p = gatewayPayload as Record<string, unknown>;
  const finalStatus = String(p.status ?? "").toUpperCase();
  const now = new Date().toISOString();

  if (finalStatus === "SUCCESSFUL") {
    const { error: txUpdateError } = await admin
      .from("payment_transactions")
      .update({
        status: "successful",
        provider_transaction_id: String(
          p.financialTransactionId ?? referenceId,
        ),
        raw_response: { callback: body, status_check: p },
        completed_at: now,
      })
      .eq("id", tx.id)
      .in("status", ["initiated", "pending"]);

    if (txUpdateError) return fail("PAYMENT_TRANSACTION_UPDATE_FAILED");

    const { error: orderError } = await admin
      .from("orders")
      .update({
        payment_status: "paid",
        status: "payment_confirmed",
        updated_at: now,
      })
      .eq("id", tx.order_id)
      .in("payment_status", ["pending", "unpaid"]);

    if (orderError) return fail("ORDER_PAYMENT_UPDATE_FAILED");

    const { error: historyError } = await admin
      .from("order_status_history")
      .insert({
        order_id: tx.order_id,
        status: "payment_confirmed",
        note: "MTN Uganda payment confirmed by callback and gateway status verification",
        changed_by: null,
      });

    if (historyError) return fail("ORDER_HISTORY_WRITE_FAILED");

    const { error: eventUpdateError } = await admin
      .from("payment_webhook_events")
      .update({
        processed: true,
        processed_at: now,
        payload: { callback: body, status_check: p },
      })
      .eq("provider", "mtn_uganda")
      .eq("event_id", eventId);

    if (eventUpdateError) return fail("WEBHOOK_EVENT_FINALIZE_FAILED");

    return json({ ok: true, processed: true, status: "successful" });
  }

  if (["FAILED", "REJECTED", "EXPIRED", "CANCELLED"].includes(finalStatus)) {
    const { error: txUpdateError } = await admin
      .from("payment_transactions")
      .update({
        status: "failed",
        raw_response: { callback: body, status_check: p },
        completed_at: now,
      })
      .eq("id", tx.id)
      .in("status", ["initiated", "pending"]);

    if (txUpdateError) return fail("PAYMENT_TRANSACTION_UPDATE_FAILED");

    const { error: orderError } = await admin
      .from("orders")
      .update({
        payment_status: "failed",
        status: "payment_pending",
        updated_at: now,
      })
      .eq("id", tx.order_id)
      .eq("payment_status", "pending");

    if (orderError) return fail("ORDER_PAYMENT_UPDATE_FAILED");

    const { error: eventUpdateError } = await admin
      .from("payment_webhook_events")
      .update({
        processed: true,
        processed_at: now,
        payload: { callback: body, status_check: p },
      })
      .eq("provider", "mtn_uganda")
      .eq("event_id", eventId);

    if (eventUpdateError) return fail("WEBHOOK_EVENT_FINALIZE_FAILED");

    return json({ ok: true, processed: true, status: "failed" });
  }

  return json({
    ok: true,
    processed: false,
    reason: "NON_FINAL_STATUS",
    status: finalStatus || "PENDING",
  });
});

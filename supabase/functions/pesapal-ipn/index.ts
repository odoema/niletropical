// pesapal-ipn — Pesapal Instant Payment Notification receiver.
//
// Deploy with JWT verification OFF (Pesapal cannot send a Supabase JWT):
//   supabase functions deploy pesapal-ipn --no-verify-jwt
//
// The request is unauthenticated, so nothing in it is trusted: we only use the
// tracking id / merchant reference to find OUR transaction, then re-query
// Pesapal with our credentials and validate reference, amount and currency
// before settling (see _shared/pesapal_settle.ts).
import { createClient } from "npm:@supabase/supabase-js@2";
import { settlePesapalTransaction } from "../_shared/pesapal_settle.ts";

const headers = { "Content-Type": "application/json" };

function ack(
  type: string,
  trackingId: string,
  merchantReference: string,
  ok: boolean,
) {
  // Pesapal retries the IPN when the body status is not 200.
  return new Response(
    JSON.stringify({
      orderNotificationType: type,
      orderTrackingId: trackingId,
      orderMerchantReference: merchantReference,
      status: ok ? 200 : 500,
    }),
    { status: 200, headers },
  );
}

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const url = new URL(req.url);
  const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
  const trackingId = String(
    url.searchParams.get("OrderTrackingId") ?? body.OrderTrackingId ?? "",
  ).trim();
  const merchantReference = String(
    url.searchParams.get("OrderMerchantReference") ??
      body.OrderMerchantReference ?? "",
  ).trim();
  const type = String(
    url.searchParams.get("OrderNotificationType") ??
      body.OrderNotificationType ?? "IPNCHANGE",
  ).slice(0, 32);

  if (
    !trackingId || !merchantReference ||
    trackingId.length > 64 || merchantReference.length > 64
  ) {
    return new Response(JSON.stringify({ error: "INVALID_IPN" }), {
      status: 400,
      headers,
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const { data: tx } = await supabase
      .from("payment_transactions")
      .select("id, provider_transaction_id")
      .eq("provider", "pesapal")
      .eq("provider_reference", merchantReference)
      .maybeSingle();

    if (!tx || tx.provider_transaction_id !== trackingId) {
      // Unknown or mismatched: acknowledge so Pesapal stops retrying junk.
      return ack(type, trackingId, merchantReference, true);
    }

    const result = await settlePesapalTransaction(supabase, tx.id);

    await supabase.from("payment_webhook_events").insert({
      provider: "pesapal",
      event_id: `${trackingId}:${new Date().toISOString()}`,
      event_type: type,
      payload: { trackingId, merchantReference, result },
      // Pesapal IPNs are unsigned; "valid" here means we verified the
      // transaction directly with the Pesapal API and the binding matched.
      signature_valid: result.ok,
      processed: result.ok,
      processed_at: new Date().toISOString(),
    });

    return ack(type, trackingId, merchantReference, result.ok);
  } catch (_) {
    return ack(type, trackingId, merchantReference, false);
  }
});

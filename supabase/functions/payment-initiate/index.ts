// payment-initiate — server-side payment initiation; client is never authority.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const METHODS = new Set([
  "mtn_momo",
  "airtel_money",
  "card",
  "cash_on_delivery",
]);

function normalize(method: string | undefined): string {
  switch (method) {
    case "mtn_direct":
    case "mtn":
      return "mtn_momo";
    case "airtel_direct":
    case "airtel":
      return "airtel_money";
    case "card_direct":
      return "card";
    case "cash":
    case "cod":
      return "cash_on_delivery";
    default:
      return method && METHODS.has(method) ? method : "mtn_momo";
  }
}

const cors = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: cors });
  }

  if (req.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const orderId = String(body.order_id ?? "").trim();
    const orderNumber = String(body.order_number ?? "").trim();
    const method = normalize(body.method);
    const clientPhone = String(body.phone ?? "").trim();

    if (!orderId && !orderNumber) {
      return json({ error: "order_id or order_number required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let order: any = null;

    if (orderId) {
      const byId = await supabase
        .from("orders")
        .select(
          "id, order_number, total, payment_status, status, payment_method, customer_phone_snapshot",
        )
        .eq("id", orderId)
        .maybeSingle();

      if (byId.error) {
        return json({ error: "ORDER_LOOKUP_FAILED", message: byId.error.message }, 500);
      }
      order = byId.data;
    }

    if (!order && orderNumber) {
      const byNumber = await supabase
        .from("orders")
        .select(
          "id, order_number, total, payment_status, status, payment_method, customer_phone_snapshot",
        )
        .eq("order_number", orderNumber)
        .maybeSingle();

      if (byNumber.error) {
        return json({ error: "ORDER_LOOKUP_FAILED", message: byNumber.error.message }, 500);
      }
      order = byNumber.data;
    }

    if (!order) {
      return json({ error: "Order not found" }, 404);
    }

    if (method === "mtn_momo") {
      if (order.payment_method !== "mtn_momo") {
        return json({
          error: "PAYMENT_METHOD_MISMATCH",
          message: "Order payment method is not MTN Mobile Money",
        }, 409);
      }

      // create_order normally puts non-COD orders directly into payment_pending.
      // Keep this repair for older orders created before that fix.
      if (order.status === "new_order") {
        const { data: transitioned, error: transitionError } = await supabase
          .from("orders")
          .update({
            status: "payment_pending",
            payment_status: "pending",
          })
          .eq("id", order.id)
          .eq("status", "new_order")
          .select(
            "id, order_number, total, payment_status, status, payment_method, customer_phone_snapshot",
          )
          .maybeSingle();

        if (transitionError) {
          return json({
            error: "ORDER_STATUS_UPDATE_FAILED",
            message: transitionError.message,
          }, 500);
        }
        if (transitioned) order = transitioned;
      }

      if (order.status !== "payment_pending") {
        return json({
          error: "ORDER_NOT_PAYABLE",
          message: "Order must be in payment_pending state",
          status: order.status,
        }, 409);
      }

      const payerPhone = String(
        order.customer_phone_snapshot ?? clientPhone ?? "",
      ).trim();

      if (!payerPhone) {
        return json({
          error: "MISSING_PAYMENT_PHONE",
          message: "The order has no checkout phone number.",
        }, 422);
      }

      const gatewayUrl =
        Deno.env.get("MTN_GATEWAY_URL") ??
        Deno.env.get("NILE_MTN_GATEWAY_URL") ??
        "https://132.145.240.116";

      const gatewaySecret =
        Deno.env.get("MTN_GATEWAY_SHARED_SECRET") ??
        Deno.env.get("NILE_MTN_GATEWAY_SECRET") ??
        Deno.env.get("GATEWAY_SHARED_SECRET");

      if (!gatewaySecret) {
        return json({ error: "MTN gateway secret is not configured" }, 500);
      }

      const reference = crypto.randomUUID();

      const gatewayResponse = await fetch(
        gatewayUrl.replace(/\/$/, "") + "/mtn/collection/request-to-pay",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Gateway-Secret": gatewaySecret,
            "Accept": "application/json",
          },
          body: JSON.stringify({
            reference_id: reference,
            external_id: order.order_number,
            amount: String(order.total),
            currency: "UGX",
            payer_party_id_type: "MSISDN",
            payer_party_id: payerPhone,
            payer_message: "Nile Tropical payment",
            payee_note: "Nile Tropical order " + order.order_number,
            transfer_type: "CUSTOM_PAYMENT",
          }),
        },
      );

      const gatewayText = await gatewayResponse.text();
      let gatewayData: any;
      try {
        gatewayData = JSON.parse(gatewayText);
      } catch {
        gatewayData = { raw: gatewayText };
      }

      const upstreamStatus =
        gatewayData?.status_code ?? gatewayResponse.status;

      if (!gatewayResponse.ok || upstreamStatus !== 202) {
        await supabase
          .from("orders")
          .update({ payment_status: "failed" })
          .eq("id", order.id);

        return json({
          error: "MTN_REQUEST_TO_PAY_FAILED",
          gateway_status: upstreamStatus,
          gateway: gatewayData,
          reference,
          order_id: order.id,
          order_number: order.order_number,
        }, 502);
      }

      return json({
        reference,
        status: "pending",
        order_id: order.id,
        order_number: order.order_number,
        method: "mtn_momo",
        instructions: "Approve the MTN Mobile Money prompt.",
      });
    }

    const reference =
      "NTI-PAY-" + order.order_number + "-" + Date.now();

    // Keep non-MTN methods isolated from the MTN path. If the legacy payments
    // table is unavailable in production, report that cleanly instead of
    // pretending the payment was initiated.
    const { error: insertError } = await supabase.from("payments").insert({
      order_id: order.id,
      method,
      amount: order.total,
      status: "pending",
      provider: method,
      provider_reference: reference,
    });

    if (insertError) {
      return json({
        error: "PAYMENT_RECORD_FAILED",
        message: insertError.message,
      }, 500);
    }

    return json({
      reference,
      status: "pending",
      order_id: order.id,
      order_number: order.order_number,
      method,
      instructions:
        method === "airtel_money"
          ? "Complete the Airtel Money payment."
          : method === "cash_on_delivery"
          ? "Payment will be collected on delivery."
          : "Complete the payment.",
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

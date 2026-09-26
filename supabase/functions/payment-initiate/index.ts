// payment-initiate — server-side payment initiation; client is never authority
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const METHODS = new Set(["mtn_momo", "airtel_money", "card", "cash_on_delivery"]);

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
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-gateway-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200, headers: cors });

  try {
    const body = await req.json();
    const order_id = body.order_id;
    const order_number = body.order_number;
    const method = normalize(body.method);

    if (!order_id && !order_number) {
      return json({ error: "order_id or order_number required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // The checkout page normally supplies the database UUID. For older or
    // idempotency-based checkout responses, also accept the displayed order
    // number so a valid order can still be resolved safely.
    let order: any = null;
    let orderError: any = null;

    if (order_id) {
      const byId = await supabase
        .from("orders")
        .select(
          "id, order_number, total, payment_status, status, payment_method, customer_phone_snapshot",
        )
        .eq("id", order_id)
        .maybeSingle();
      order = byId.data;
      orderError = byId.error;
    }

    if (!order && order_number) {
      const byNumber = await supabase
        .from("orders")
        .select(
          "id, order_number, total, payment_status, status, payment_method, customer_phone_snapshot",
        )
        .eq("order_number", order_number)
        .maybeSingle();
      order = byNumber.data;
      orderError = byNumber.error;
    }

    if (orderError || !order) {
      return json({
        error: "Order not found",
        order_id: order_id ?? null,
        order_number: order_number ?? null,
      }, 404);
    }

    if (method === "mtn_momo") {
      // Older live create_order deployments may still leave a non-COD order
      // in new_order. MTN payment initiation is the authoritative transition
      // point: move that order into payment_pending atomically before charging.
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

      if (order.payment_method !== "mtn_momo") {
        return json({
          error: "PAYMENT_METHOD_MISMATCH",
          message: "Order payment method is not MTN Mobile Money",
        }, 409);
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

      // The live production database currently does not expose the legacy
      // public.payments table. Do not block MTN charging on that table.
      // The provider reference is returned to the client and payment-status
      // reconciles the verified MTN result directly onto orders.payment_status.
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
            payer_party_id: order.customer_phone_snapshot ?? body.phone ?? "",
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

      const upstreamStatus = gatewayData?.status_code ?? gatewayResponse.status;

      if (!gatewayResponse.ok || upstreamStatus !== 202) {
        await supabase
          .from("payments")
          .update({ status: "failed" })
          .eq("id", payment.id);

        return json({
          error: "MTN_REQUEST_TO_PAY_FAILED",
          gateway_status: upstreamStatus,
          gateway: gatewayData,
          reference,
        }, 502);
      }

      return json({
        reference,
        status: "pending",
        order_id,
        method: "mtn_momo",
        instructions: "Approve the MTN Mobile Money prompt.",
      });
    }

    const reference = "NTI-PAY-" + order.order_number + "-" + Date.now();

    const { error: insertError } = await supabase.from("payments").insert({
      order_id,
      method,
      amount: order.total,
      status: "pending",
      provider: method,
      provider_reference: reference,
    });

    if (insertError) return json({ error: insertError.message }, 500);

    return json({
      reference,
      status: "pending",
      order_id,
      method,
      instructions:
        method === "airtel_money"
          ? "Complete the Airtel Money payment."
          : method === "cash_on_delivery"
          ? "Payment will be collected on delivery."
          : "Complete the payment.",
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

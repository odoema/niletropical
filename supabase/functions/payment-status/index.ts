// payment-status — server-side MTN verification and order reconciliation
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-gateway-secret",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: cors });
  }

  try {
    const url = new URL(req.url);
    let body: any = {};
    if (req.method !== "GET") {
      body = await req.json().catch(() => ({}));
    }

    const reference =
      url.searchParams.get("reference") ??
      body.reference ??
      null;
    const orderId = body.order_id ?? url.searchParams.get("order_id");
    const orderNumber =
      body.order_number ?? url.searchParams.get("order_number");

    if (!reference) return json({ error: "reference required" }, 400);
    if (!orderId && !orderNumber) {
      return json({ error: "order_id or order_number required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let order: any = null;
    let orderError: any = null;

    if (orderId) {
      const byId = await supabase
        .from("orders")
        .select("id, order_number, status, payment_status, payment_method, total")
        .eq("id", orderId)
        .maybeSingle();
      order = byId.data;
      orderError = byId.error;
    }

    if (!order && orderNumber) {
      const byNumber = await supabase
        .from("orders")
        .select("id, order_number, status, payment_status, payment_method, total")
        .eq("order_number", orderNumber)
        .maybeSingle();
      order = byNumber.data;
      orderError = byNumber.error;
    }

    if (orderError) {
      return json({ error: orderError.message }, 500);
    }
    if (!order) {
      return json({
        error: "Order not found",
        order_id: orderId ?? null,
        order_number: orderNumber ?? null,
      }, 404);
    }

    if (order.payment_method !== "mtn_momo") {
      return json({
        reference,
        status: order.payment_status,
        order_id: order.id,
        order_number: order.order_number,
        method: order.payment_method,
        reconciled: order.payment_status === "paid",
      });
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

    const gatewayResponse = await fetch(
      gatewayUrl.replace(/\/$/, "") +
        "/mtn/collection/request-to-pay/" +
        encodeURIComponent(reference),
      {
        method: "GET",
        headers: {
          "X-Gateway-Secret": gatewaySecret,
          "Accept": "application/json",
        },
      },
    );

    const gatewayText = await gatewayResponse.text();
    let gatewayData: any;
    try {
      gatewayData = JSON.parse(gatewayText);
    } catch {
      gatewayData = { raw: gatewayText };
    }

    if (!gatewayResponse.ok) {
      return json({
        reference,
        status: order.payment_status,
        order_id: order.id,
        order_number: order.order_number,
        gateway_http_status: gatewayResponse.status,
        gateway: gatewayData,
      }, 502);
    }

    const upstreamStatus = gatewayData?.body?.status ?? null;
    let newPaymentStatus = order.payment_status ?? "pending";

    if (upstreamStatus === "SUCCESSFUL") {
      newPaymentStatus = "paid";
    } else if (
      upstreamStatus === "FAILED" ||
      upstreamStatus === "REJECTED"
    ) {
      newPaymentStatus = "failed";
    } else if (upstreamStatus === "PENDING") {
      newPaymentStatus = "pending";
    }

    if (newPaymentStatus !== order.payment_status) {
      const { error: updateOrderError } = await supabase
        .from("orders")
        .update({ payment_status: newPaymentStatus })
        .eq("id", order.id);

      if (updateOrderError) {
        return json({
          error: updateOrderError.message,
          reference,
          order_id: order.id,
          payment_status: order.payment_status,
          gateway_status: upstreamStatus,
        }, 500);
      }
    }

    return json({
      reference,
      status: newPaymentStatus,
      order_id: order.id,
      order_number: order.order_number,
      method: "mtn_momo",
      gateway_status: upstreamStatus,
      financial_transaction_id:
        gatewayData?.body?.financialTransactionId ?? null,
      gateway_amount: gatewayData?.body?.amount ?? null,
      gateway_currency: gatewayData?.body?.currency ?? null,
      reconciled: newPaymentStatus === "paid",
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

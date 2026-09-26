// payment-status — server-side MTN verification and reconciliation
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  try {
    let reference: string | null = null;
    const url = new URL(req.url);
    reference = url.searchParams.get("reference");

    if (!reference) {
      const body = await req.json().catch(() => ({}));
      reference = body.reference ?? null;
    }

    if (!reference) return json({ error: "reference required" }, 400);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select("id, order_id, status, method, provider_reference, amount")
      .eq("provider_reference", reference)
      .maybeSingle();

    if (paymentError) {
      return json({ error: paymentError.message }, 500);
    }

    if (!payment) return json({ error: "Not found" }, 404);

    // Only MTN payments are verified against the MTN gateway.
    if (payment.method !== "mtn_momo") {
      return json({
        reference,
        status: payment.status,
        order_id: payment.order_id,
        method: payment.method,
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
        status: payment.status,
        order_id: payment.order_id,
        gateway_http_status: gatewayResponse.status,
        gateway: gatewayData,
      }, 502);
    }

    const upstreamStatus = gatewayData?.body?.status ?? null;
    let newPaymentStatus = payment.status;

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

    if (newPaymentStatus !== payment.status) {
      const { error: updatePaymentError } = await supabase
        .from("payments")
        .update({ status: newPaymentStatus })
        .eq("id", payment.id);

      if (updatePaymentError) {
        return json({
          error: updatePaymentError.message,
          reference,
          gateway_status: upstreamStatus,
        }, 500);
      }

      if (newPaymentStatus === "paid") {
        const { error: updateOrderError } = await supabase
          .from("orders")
          .update({
            payment_status: "paid",
          })
          .eq("id", payment.order_id);

        if (updateOrderError) {
          return json({
            error: updateOrderError.message,
            reference,
            payment_status: "paid",
            gateway_status: upstreamStatus,
          }, 500);
        }
      }
    }

    return json({
      reference,
      status: newPaymentStatus,
      order_id: payment.order_id,
      method: payment.method,
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

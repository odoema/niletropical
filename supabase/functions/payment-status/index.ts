// payment-status — server-side MTN verification and order reconciliation.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: cors });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: cors });
  }

  if (req.method !== "GET" && req.method !== "POST") {
    return json({ error: "GET or POST required" }, 405);
  }

  try {
    const url = new URL(req.url);
    const body =
      req.method === "GET" ? {} : await req.json().catch(() => ({}));

    const reference =
      url.searchParams.get("reference") ?? body.reference ?? null;
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

    if (orderId) {
      const result = await supabase
        .from("orders")
        .select(
          "id, order_number, status, payment_status, payment_method, total, customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot",
        )
        .eq("id", orderId)
        .maybeSingle();

      if (result.error) {
        return json(
          { error: "ORDER_LOOKUP_FAILED", message: result.error.message },
          500,
        );
      }
      order = result.data;
    }

    if (!order && orderNumber) {
      const result = await supabase
        .from("orders")
        .select(
          "id, order_number, status, payment_status, payment_method, total, customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot",
        )
        .eq("order_number", orderNumber)
        .maybeSingle();

      if (result.error) {
        return json(
          { error: "ORDER_LOOKUP_FAILED", message: result.error.message },
          500,
        );
      }
      order = result.data;
    }

    if (!order) {
      return json({ error: "Order not found" }, 404);
    }

    if (order.payment_method !== "mtn_momo") {
      return json({
        reference,
        status: order.payment_status,
        order_id: order.id,
        order_number: order.order_number,
        total: order.total,
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
      return json(
        {
          reference,
          status: order.payment_status,
          order_id: order.id,
          order_number: order.order_number,
          gateway_http_status: gatewayResponse.status,
          gateway: gatewayData,
        },
        502,
      );
    }

    const gatewayBody = gatewayData?.body ?? gatewayData ?? {};
    const upstreamStatus = gatewayBody?.status ?? null;
    const gatewayExternalId = gatewayBody?.externalId ?? null;

    // Bind the provider response to the order before changing payment state.
    if (
      gatewayExternalId &&
      String(gatewayExternalId) !== String(order.order_number)
    ) {
      return json(
        {
          error: "PAYMENT_ORDER_MISMATCH",
          reference,
          order_id: order.id,
          order_number: order.order_number,
          gateway_external_id: gatewayExternalId,
        },
        409,
      );
    }

    const previousPaymentStatus = order.payment_status ?? "pending";
    let newPaymentStatus = previousPaymentStatus;

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
      const update: Record<string, string> = {
        payment_status: newPaymentStatus,
      };

      if (newPaymentStatus === "paid" && order.status === "payment_pending") {
        update.status = "new_order";
      }

      const { error } = await supabase
        .from("orders")
        .update(update)
        .eq("id", order.id);

      if (error) {
        return json(
          {
            error: "ORDER_PAYMENT_UPDATE_FAILED",
            message: error.message,
            reference,
            order_id: order.id,
            payment_status: order.payment_status,
            gateway_status: upstreamStatus,
          },
          500,
        );
      }

      // Keep the local representation used below consistent with the DB write.
      order.payment_status = newPaymentStatus;
      if (update.status) order.status = update.status;
    }

    // Payment is authoritative. Email is a secondary notification and can
    // never make a successful payment fail.
    //
    // Only send the confirmation email on the transition to paid.
    // Repeated polling of an already-paid MTN transaction must not
    // repeatedly invoke the notification service.
    const paymentJustBecamePaid =
      newPaymentStatus === "paid" && previousPaymentStatus !== "paid";

    let notification: unknown = null;

    if (paymentJustBecamePaid) {
      const functionBaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const serviceRoleKey =
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

      if (functionBaseUrl && serviceRoleKey) {
        try {
          const notificationResponse = await fetch(
            functionBaseUrl.replace(/\/$/, "") +
              "/functions/v1/notification-dispatch",
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${serviceRoleKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                event: "payment_confirmed",
                order_id: order.id,
                order_number: order.order_number,
                customer_name: order.customer_name_snapshot ?? "",
                email: order.customer_email_snapshot ?? "",
                phone: order.customer_phone_snapshot ?? "",
                total: order.total,
                payment_method: order.payment_method,
                status: order.status ?? "new_order",
                channels: ["email"],
              }),
            },
          );

          const notificationText = await notificationResponse.text();

          try {
            notification = JSON.parse(notificationText);
          } catch {
            notification = {
              http_status: notificationResponse.status,
              raw: notificationText,
            };
          }
        } catch (error) {
          notification = {
            status: "dispatch_failed",
            message: String(error),
          };
        }
      } else {
        notification = {
          status: "not_configured",
          message: "Supabase function environment is incomplete",
        };
      }
    }

    return json({
      reference,
      status: newPaymentStatus,
      order_id: order.id,
      order_number: order.order_number,
      total: order.total,
      method: "mtn_momo",
      gateway_status: upstreamStatus,
      financial_transaction_id:
        gatewayBody?.financialTransactionId ?? null,
      gateway_amount: gatewayBody?.amount ?? null,
      gateway_currency: gatewayBody?.currency ?? null,
      reconciled: newPaymentStatus === "paid",
      notification,
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

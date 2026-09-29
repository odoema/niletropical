// payment-initiate — server-side payment initiation; client is never authority.
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  parsePesapalEnvironment,
  requestPesapalToken,
  submitPesapalOrder,
} from "../_shared/pesapal.ts";

// The MTN MoMo Developer sandbox accepts EUR only. The Oracle gateway should
// translate this provider-facing currency according to its configured MTN
// environment. Production MTN Uganda should set MTN_GATEWAY_CURRENCY=UGX.
const MTN_GATEWAY_CURRENCY = (Deno.env.get("MTN_GATEWAY_CURRENCY") ?? "EUR").toUpperCase();
const MTN_GATEWAY_MODE = (Deno.env.get("MTN_GATEWAY_MODE") ?? "sandbox").toLowerCase();
const MTN_SANDBOX_UGX_PER_EUR = Number(Deno.env.get("MTN_SANDBOX_UGX_PER_EUR") ?? "4000");
// MTN documents that any non-predefined MSISDN produces SUCCESS in sandbox.
// This is an explicit sandbox-only test identity so checkout can exercise the
// complete success path without depending on a real Uganda wallet prompt.
const MTN_SANDBOX_TEST_MSISDN = String(
  Deno.env.get("MTN_SANDBOX_TEST_MSISDN") ?? "46733123499",
).trim();

function providerAmountFromUgx(ugx: number): string {
  if (!Number.isFinite(ugx) || ugx <= 0) throw new Error("INVALID_UGX_AMOUNT");
  if (MTN_GATEWAY_MODE === "sandbox") {
    if (MTN_GATEWAY_CURRENCY !== "EUR") throw new Error("MTN_SANDBOX_MUST_USE_EUR");
    // The deployed Oracle sandbox adapter intentionally normalizes every
    // Request-to-Pay to its fixed MTN sandbox test amount (EUR 1.00).
    // Record/send that exact provider-facing amount so payment-status
    // reconciliation cannot reject the transaction as an amount mismatch.
    return "1.00";
  }
  if (MTN_GATEWAY_CURRENCY !== "UGX") throw new Error("MTN_PRODUCTION_MUST_USE_UGX");
  return Math.round(ugx).toString();
}

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

Deno.serve(async (req) => {
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
      let providerAmount: string;
      try {
        providerAmount = providerAmountFromUgx(Number(order.total));
      } catch (error) {
        return json({ error: "MTN_CURRENCY_CONFIGURATION_ERROR", message: String(error) }, 500);
      }

      const providerPayerPhone = MTN_GATEWAY_MODE === "sandbox"
        ? MTN_SANDBOX_TEST_MSISDN
        : payerPhone;

      if (MTN_GATEWAY_MODE === "sandbox" && !/^[0-9]{8,15}$/.test(providerPayerPhone)) {
        return json({
          error: "MTN_SANDBOX_TEST_MSISDN_INVALID",
          message: "Sandbox test MSISDN must contain 8-15 digits.",
        }, 500);
      }

      const providerRequest = {
        amount: providerAmount,
        currency: MTN_GATEWAY_CURRENCY,
        external_id: order.order_number,
        payer_party_id_type: "MSISDN",
        payer_party_id: providerPayerPhone,
        transfer_type: "CUSTOM_PAYMENT",
      };

      const { data: paymentTx, error: paymentTxError } = await supabase
        .from("payment_transactions")
        .insert({
          order_id: order.id,
          provider: "mtn_gateway",
          method: "mtn_momo",
          provider_reference: reference,
          idempotency_key: reference,
          amount: order.total,
          currency: "UGX",
          status: "initiated",
          raw_response: {
            payment_environment: MTN_GATEWAY_MODE,
            merchant_amount: Number(order.total),
            merchant_currency: "UGX",
            provider_currency: MTN_GATEWAY_CURRENCY,
            provider_amount: Number(providerAmount),
            provider_fx: MTN_GATEWAY_MODE === "sandbox"
              ? { model: "fixed_test_rate", ugx_per_eur: MTN_SANDBOX_UGX_PER_EUR }
              : null,
            request: providerRequest,
          },
        })
        .select("id")
        .single();

      if (paymentTxError) {
        return json({
          error: "PAYMENT_TRANSACTION_CREATE_FAILED",
          message: paymentTxError.message,
        }, 500);
      }

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
            amount: providerAmount,
            currency: MTN_GATEWAY_CURRENCY,
            payer_party_id_type: "MSISDN",
            payer_party_id: providerPayerPhone,
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
          .from("payment_transactions")
          .update({
            status: "failed",
            raw_response: { request: providerRequest, response: gatewayData },
            completed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", paymentTx.id);

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

      await supabase
        .from("payment_transactions")
        .update({
          status: "pending",
          raw_response: { request: providerRequest, response: gatewayData },
          updated_at: new Date().toISOString(),
        })
        .eq("id", paymentTx.id);

      return json({
        reference,
        status: "pending",
        order_id: order.id,
        order_number: order.order_number,
        method: "mtn_momo",
        instructions: MTN_GATEWAY_MODE === "sandbox"
          ? "Sandbox payment submitted using the MTN success test identity; waiting for the sandbox final status."
          : "Approve the MTN Mobile Money prompt.",
      });
    }

    if (method === "card") {
      // Card / international payments go through Pesapal (hosted checkout).
      // Kill switch: nothing reaches Pesapal until this is explicitly "true".
      if (Deno.env.get("PESAPAL_ENABLED") !== "true") {
        return json({
          error: "PAYMENT_PROVIDER_NOT_CONFIGURED",
          message: "Card payments are not enabled yet. No payment was recorded as successful.",
          method,
        }, 503);
      }
      if (order.payment_method !== "card") {
        return json({
          error: "PAYMENT_METHOD_MISMATCH",
          message: "Order payment method is not card",
        }, 409);
      }
      if (order.payment_status === "paid") {
        return json({ error: "ORDER_ALREADY_PAID", message: "This order is already paid." }, 409);
      }
      if (order.status === "new_order") {
        const { data: transitioned } = await supabase
          .from("orders")
          .update({ status: "payment_pending", payment_status: "pending" })
          .eq("id", order.id)
          .eq("status", "new_order")
          .select("id, order_number, total, payment_status, status, payment_method, customer_phone_snapshot")
          .maybeSingle();
        if (transitioned) order = transitioned;
      }
      if (order.status !== "payment_pending") {
        return json({
          error: "ORDER_NOT_PAYABLE",
          message: "Order must be in payment_pending state",
          status: order.status,
        }, 409);
      }

      // Reuse a recent unfinished payment link instead of creating a second
      // live transaction for the same order (retry / resend button).
      const recent = await supabase
        .from("payment_transactions")
        .select("provider_reference, raw_response, created_at")
        .eq("order_id", order.id)
        .eq("provider", "pesapal")
        .eq("status", "pending")
        .gte("created_at", new Date(Date.now() - 15 * 60 * 1000).toISOString())
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      const reusable = (recent.data?.raw_response as Record<string, unknown> | null)
        ?.redirect_url;
      if (recent.data?.provider_reference && typeof reusable === "string") {
        return json({
          reference: recent.data.provider_reference,
          status: "pending",
          order_id: order.id,
          order_number: order.order_number,
          method: "card",
          redirect_url: reusable,
          instructions: "Complete your payment in the secure payment window.",
        });
      }

      let environment;
      try {
        environment = parsePesapalEnvironment(Deno.env.get("PESAPAL_ENVIRONMENT"));
      } catch (error) {
        return json({ error: "PESAPAL_NOT_CONFIGURED", message: String(error) }, 500);
      }
      const consumerKey = Deno.env.get("PESAPAL_CONSUMER_KEY") ?? "";
      const consumerSecret = Deno.env.get("PESAPAL_CONSUMER_SECRET") ?? "";
      const ipnId = Deno.env.get("PESAPAL_IPN_ID") ?? "";
      const callbackUrl = Deno.env.get("PESAPAL_CALLBACK_URL") ??
        "https://niletropicaluganda.com/app/";
      if (!consumerKey || !consumerSecret || !ipnId) {
        return json({
          error: "PESAPAL_NOT_CONFIGURED",
          message: "Pesapal credentials or IPN id are missing.",
        }, 500);
      }

      const { data: extra } = await supabase
        .from("orders")
        .select("customer_name_snapshot, customer_email_snapshot, delivery_address_snapshot")
        .eq("id", order.id)
        .maybeSingle();
      const fullName = String(extra?.customer_name_snapshot ?? "").trim();
      const [firstName, ...rest] = fullName.split(/\s+/);
      const address = (extra?.delivery_address_snapshot ?? {}) as Record<string, unknown>;
      const payerPhone = String(order.customer_phone_snapshot ?? clientPhone ?? "").trim();
      const payerEmail = String(extra?.customer_email_snapshot ?? "").trim();
      if (!payerEmail && !payerPhone) {
        return json({
          error: "MISSING_PAYER_CONTACT",
          message: "The order needs an email or phone number for card payment.",
        }, 422);
      }

      const reference = crypto.randomUUID();
      const pesapalOrder = {
        id: reference,
        currency: "UGX",
        amount: Number(order.total),
        description: `Nile Tropical order ${order.order_number}`.slice(0, 100),
        callback_url: callbackUrl,
        notification_id: ipnId,
        billing_address: {
          email_address: payerEmail,
          phone_number: payerPhone,
          country_code: "UG",
          first_name: firstName || "Customer",
          last_name: rest.join(" "),
          line_1: String(address.address_line ?? address.line_1 ?? ""),
          city: String(address.city ?? ""),
        },
      };

      const { data: paymentTx, error: paymentTxError } = await supabase
        .from("payment_transactions")
        .insert({
          order_id: order.id,
          provider: "pesapal",
          method: "card",
          provider_reference: reference,
          idempotency_key: reference,
          amount: order.total,
          currency: "UGX",
          status: "initiated",
          raw_response: { payment_environment: environment, request: pesapalOrder },
        })
        .select("id")
        .single();
      if (paymentTxError) {
        return json({
          error: "PAYMENT_TRANSACTION_CREATE_FAILED",
          message: paymentTxError.message,
        }, 500);
      }

      try {
        const accessToken = await requestPesapalToken({
          environment,
          consumerKey,
          consumerSecret,
        });
        const submitted = await submitPesapalOrder({
          environment,
          accessToken,
          order: pesapalOrder,
        });
        await supabase
          .from("payment_transactions")
          .update({
            status: "pending",
            provider_transaction_id: submitted.trackingId,
            raw_response: {
              payment_environment: environment,
              request: pesapalOrder,
              order_tracking_id: submitted.trackingId,
              redirect_url: submitted.redirectUrl,
            },
            updated_at: new Date().toISOString(),
          })
          .eq("id", paymentTx.id);

        return json({
          reference,
          status: "pending",
          order_id: order.id,
          order_number: order.order_number,
          method: "card",
          redirect_url: submitted.redirectUrl,
          instructions: "Complete your payment in the secure payment window.",
        });
      } catch (error) {
        await supabase
          .from("payment_transactions")
          .update({
            status: "failed",
            raw_response: {
              payment_environment: environment,
              request: pesapalOrder,
              error: String(error),
            },
            completed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", paymentTx.id);
        return json({
          error: "PESAPAL_ORDER_SUBMIT_FAILED",
          message: "Could not start the card payment. Please try again.",
          reference,
        }, 502);
      }
    }

    if (method === "cash_on_delivery") {
      return json({
        error: "COD_PAYMENT_INITIATION_NOT_ALLOWED",
        message: "Cash on delivery is confirmed at checkout and does not use the payment gateway.",
      }, 409);
    }

    if (method === "airtel_money") {
      return json({
        error: "PAYMENT_PROVIDER_NOT_CONFIGURED",
        message: "The Airtel Money payment provider is not configured yet. No payment was recorded as successful.",
        method,
      }, 503);
    }

    return json({
      error: "UNSUPPORTED_PAYMENT_METHOD",
      message: "This payment method is not supported.",
      method,
    }, 400);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
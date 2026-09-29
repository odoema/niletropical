// Settlement for Pesapal card payments. Used by payment-status (customer poll)
// and pesapal-ipn (Pesapal server callback) so both paths behave identically.
//
// Trust model: neither caller's input is trusted. The transaction status is
// always re-fetched from Pesapal with our own credentials and bound to the
// local merchant reference, amount and currency before any order is changed.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  getPesapalTransactionStatus,
  normalizePesapalStatus,
  parsePesapalEnvironment,
  requestPesapalToken,
  validatePesapalStatusBinding,
  type PesapalTransactionStatus,
} from "./pesapal.ts";

export interface SettlementDecision {
  txStatus: "pending" | "successful" | "failed" | "refunded";
  // null = leave the order's payment_status unchanged.
  orderPaymentStatus: "paid" | "failed" | null;
}

export function decideSettlement(
  status: PesapalTransactionStatus,
): SettlementDecision {
  switch (status) {
    case "completed":
      return { txStatus: "successful", orderPaymentStatus: "paid" };
    case "failed":
    case "invalid":
      return { txStatus: "failed", orderPaymentStatus: "failed" };
    case "reversed":
      // A reversal after payment needs a human decision; record it only.
      return { txStatus: "refunded", orderPaymentStatus: null };
    default:
      return { txStatus: "pending", orderPaymentStatus: null };
  }
}

export type SettleResult =
  | {
    ok: true;
    reference: string;
    status: "paid" | "failed" | "pending" | "refunded";
    orderId: string;
    orderNumber: string;
    total: number;
    method: string;
    paymentMethodDescription: string | null;
    confirmationCode: string | null;
    justPaid: boolean;
  }
  | { ok: false; reason: string; reference?: string };

const ORDER_COLUMNS =
  "id, order_number, status, payment_status, payment_method, total, currency, customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot";

export async function settlePesapalTransaction(
  supabase: SupabaseClient,
  txId: string,
): Promise<SettleResult> {
  const txResult = await supabase
    .from("payment_transactions")
    .select(
      "id, order_id, provider, method, provider_reference, provider_transaction_id, amount, currency, status, raw_response",
    )
    .eq("id", txId)
    .maybeSingle();
  const tx = txResult.data;
  if (txResult.error || !tx) return { ok: false, reason: "TX_LOOKUP_FAILED" };
  if (tx.provider !== "pesapal" || tx.method !== "card") {
    return { ok: false, reason: "TX_NOT_PESAPAL" };
  }
  if (!tx.provider_transaction_id || !tx.provider_reference) {
    return { ok: false, reason: "TX_MISSING_PROVIDER_IDS" };
  }

  const orderResult = await supabase
    .from("orders")
    .select(ORDER_COLUMNS)
    .eq("id", tx.order_id)
    .maybeSingle();
  const order = orderResult.data;
  if (orderResult.error || !order) {
    return { ok: false, reason: "ORDER_LOOKUP_FAILED" };
  }

  const environment = parsePesapalEnvironment(Deno.env.get("PESAPAL_ENVIRONMENT"));
  const accessToken = await requestPesapalToken({
    environment,
    consumerKey: Deno.env.get("PESAPAL_CONSUMER_KEY") ?? "",
    consumerSecret: Deno.env.get("PESAPAL_CONSUMER_SECRET") ?? "",
  });
  const providerStatus = await getPesapalTransactionStatus({
    environment,
    accessToken,
    trackingId: tx.provider_transaction_id,
  });

  const binding = validatePesapalStatusBinding(providerStatus, {
    merchantReference: tx.provider_reference,
    amount: Number(tx.amount),
    currency: tx.currency,
  });
  if (!binding.ok) {
    // Never settle on a mismatch. Keep the evidence for finance to review.
    await supabase.from("payment_transactions").update({
      raw_response: {
        ...(tx.raw_response ?? {}),
        binding_error: binding.reason,
        response: providerStatus,
      },
      updated_at: new Date().toISOString(),
    }).eq("id", tx.id);
    return { ok: false, reason: binding.reason, reference: tx.provider_reference };
  }

  const normalized = normalizePesapalStatus(
    providerStatus.status_code,
    providerStatus.payment_status_description,
  );
  const decision = decideSettlement(normalized);
  const terminal = decision.txStatus !== "pending";

  await supabase.from("payment_transactions").update({
    status: decision.txStatus,
    completed_at: terminal ? new Date().toISOString() : null,
    raw_response: { ...(tx.raw_response ?? {}), response: providerStatus },
    updated_at: new Date().toISOString(),
  }).eq("id", tx.id);

  let justPaid = false;
  let orderPaymentStatus: string = order.payment_status;

  if (decision.orderPaymentStatus === "paid") {
    const update: Record<string, string> = { payment_status: "paid" };
    // Same convention as the MTN flow: paid orders leave payment_pending.
    if (order.status === "payment_pending") update.status = "new_order";
    const { data: changed, error } = await supabase
      .from("orders")
      .update(update)
      .eq("id", order.id)
      .neq("payment_status", "paid") // makes IPN + poll race-safe
      .select("id");
    if (error) return { ok: false, reason: "ORDER_PAYMENT_UPDATE_FAILED" };
    justPaid = (changed?.length ?? 0) > 0;
    orderPaymentStatus = "paid";
  } else if (
    decision.orderPaymentStatus === "failed" &&
    order.payment_status !== "paid"
  ) {
    await supabase.from("orders").update({ payment_status: "failed" })
      .eq("id", order.id).neq("payment_status", "paid");
    orderPaymentStatus = "failed";
  }

  if (justPaid) await notifyPaymentConfirmed(order);

  return {
    ok: true,
    reference: tx.provider_reference,
    status: decision.txStatus === "refunded"
      ? "refunded"
      : orderPaymentStatus === "paid"
      ? "paid"
      : decision.txStatus === "failed"
      ? "failed"
      : "pending",
    orderId: order.id,
    orderNumber: order.order_number,
    total: Number(order.total),
    method: "card",
    paymentMethodDescription: providerStatus.payment_method ?? null,
    confirmationCode: providerStatus.confirmation_code ?? null,
    justPaid,
  };
}

// Email is secondary: it can never make a successful payment fail.
async function notifyPaymentConfirmed(order: Record<string, unknown>) {
  const base = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!base || !key) return;
  try {
    await fetch(base.replace(/\/$/, "") + "/functions/v1/notification-dispatch", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        event: "payment_confirmed",
        order_id: order.id,
        order_number: order.order_number,
        customer_name: order.customer_name_snapshot ?? "",
        email: order.customer_email_snapshot ?? "",
        phone: order.customer_phone_snapshot ?? "",
        total: order.total,
        payment_method: "card",
        status: "new_order",
        channels: ["email"],
      }),
    });
  } catch (_) { /* logged by the dispatcher; never block settlement */ }
}

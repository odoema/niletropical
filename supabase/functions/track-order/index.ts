// track-order — server-side public order tracking.
// The client supplies an order number (or legacy order UUID) plus the
// checkout phone. The service-role client reads the canonical order snapshot
// and returns a stable tracking payload without relying on a stale SQL RPC.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function digits(value: unknown): string {
  return String(value ?? "").replace(/\D/g, "");
}

function sameUgandaPhone(a: unknown, b: unknown): boolean {
  const left = digits(a);
  const right = digits(b);
  if (left.length < 9 || right.length < 9) return false;
  return left.slice(-9) === right.slice(-9);
}

function looksLikeUuid(value: string): boolean {
  return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/.test(value);
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
    const phone = String(body.phone ?? "").trim();

    if ((!orderId && !orderNumber) || !phone) {
      return json({
        error: "order_number or order_id and phone are required",
      }, 400);
    }

    if (orderId && !looksLikeUuid(orderId)) {
      return json({ error: "Invalid order_id" }, 400);
    }

    if (digits(phone).length < 9) {
      return json({ error: "Invalid phone number" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let order: any = null;
    // Older tracking links used the database UUID in the order-number slot.
    // Treat a UUID-shaped order_number as an order_id before the
    // human-facing order_number lookup.
    const legacyOrderId = orderId || (looksLikeUuid(orderNumber) ? orderNumber : "");

    if (legacyOrderId) {
      const byId = await supabase
        .from("orders")
        .select(
          "id, order_number, status, payment_status, total, created_at, customer_phone_snapshot",
        )
        .eq("id", legacyOrderId)
        .maybeSingle();

      if (byId.error) {
        return json({ error: "TRACKING_LOOKUP_FAILED", message: byId.error.message }, 500);
      }
      order = byId.data;
    }

    if (!order && orderNumber && !looksLikeUuid(orderNumber)) {
      const byNumber = await supabase
        .from("orders")
        .select(
          "id, order_number, status, payment_status, total, created_at, customer_phone_snapshot",
        )
        .eq("order_number", orderNumber)
        .maybeSingle();

      if (byNumber.error) {
        return json({ error: "TRACKING_LOOKUP_FAILED", message: byNumber.error.message }, 500);
      }
      order = byNumber.data;
    }

    // Do not disclose whether an order exists when the phone does not match.
    if (!order || !sameUgandaPhone(order.customer_phone_snapshot, phone)) {
      return json({ found: false });
    }

    const history = await supabase
      .from("order_status_history")
      .select("status, note, created_at")
      .eq("order_id", order.id)
      .order("created_at", { ascending: true });

    if (history.error) {
      return json({
        error: "TRACKING_HISTORY_LOOKUP_FAILED",
        message: history.error.message,
      }, 500);
    }

    const shipment = await supabase
      .from("shipments")
      .select("id, status, courier_id, updated_at, created_at")
      .eq("order_id", order.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (shipment.error) {
      return json({
        error: "TRACKING_SHIPMENT_LOOKUP_FAILED",
        message: shipment.error.message,
      }, 500);
    }

    return json({
      found: true,
      order_id: order.id,
      order_number: order.order_number,
      status: order.status,
      payment_status: order.payment_status,
      total: order.total,
      created_at: order.created_at,
      timeline: history.data ?? [],
      shipment: shipment.data ?? null,
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

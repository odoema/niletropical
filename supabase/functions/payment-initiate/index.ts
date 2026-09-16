// payment-initiate — writes payments row; never treats the client as authority
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: { "Access-Control-Allow-Origin": "*" } });
  }
  try {
    const body = await req.json();
    const order_id = body.order_id;
    const method = normalize(body.method);
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: order, error } = await supabase
      .from("orders")
      .select("id, order_number, total, payment_status")
      .eq("id", order_id)
      .single();
    if (error || !order) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
    const reference = `NTI-PAY-${order.order_number}-${Date.now()}`;
    const { error: insertError } = await supabase.from("payments").insert({
      order_id,
      method,
      amount: order.total,
      status: "pending",
      provider: method,
      provider_reference: reference,
    });
    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
    const momo = method === "mtn_momo" || method === "airtel_money";
    return new Response(
      JSON.stringify({
        reference,
        status: "pending",
        order_id,
        method,
        instructions: momo
          ? "Approve the prompt on your phone"
          : "Complete card payment",
      }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});
